##################################################################
# Load Packages
##################################################################
using Pumas
using Serialization, StableRNGs, Random, Dates
using DataFramesMeta, CSV, ShiftedArrays, CategoricalArrays
using CairoMakie, AlgebraOfGraphics

##################################################################
# Confirm or Set OUTDIR
##################################################################
#! If OUTDIR has changed set to appropriate DIR by using relative path
#! for result folder of interest

#OUTDIR = "2023-11-04T20:00:47"

##################################################################
# Explore Structure of Results
##################################################################
# final df
mysims = deserialize(joinpath("results",OUTDIR,"mysims.jls"))

# each row of sims contains an array of 5000 patients
#mysims.sims[1] #* first set of 5000 patients
#mysims.sims[1][1] #* first patient from first set


##################################################################
# Combining Profiles
##################################################################
#* goal is create a dataframe that contains all profiles for all sims
#* start by extracting profile from patient dictionary and adding them as col in results df
mysims[!, :profiles] = map(eachrow(mysims)) do r

    # df of individual sims becomes a SimulatedPopulation
    # this way only have to call DataFrame once
    profiles = [pt["profile"] for pt in r.sims]

    # convert sims to df
    df = DataFrame(profiles);

    # convert ids to integer
    df[!, :id] .= parse.(Int64, df.id)

    # add items for filtering later
    df[!, :runid] .= r.runid
    df[!, :skip_cday7] .= r.scenarios.SKIP_CDAY7

    # return combined df
    return df

end;

# combined df of all simulated obs
profiles = reduce(vcat, mysims.profiles);

# convert runid to categorical value for use in summaries
profiles[!, :runlabel] = categorical(profiles.runid);
#? why can't this be converted in place
#//recode!(events.runlabel, 1=>"BLREF",2=>"EARLY6MG",3=>"ADJ4MG",4=>"PUB4MG",5=>"PUB6MG",6=>"PUB8MG")
profiles[!, :runlabel] = recode(profiles.runlabel, [Pair(r.runid,r.labels) for r in eachrow(mysims)]...);


##################################################################
# Combining Trial Events
##################################################################
#* The overall goal is to create a single df with trial events for all scenarios in mysims
# start by adding a column wherein each row contains a df of combined trial events for that row's patients
mysims[!, :trial_events] = map(eachrow(mysims)) do r

    # will return a vector of dataframes that contain trial events
    tev = map(r.sims) do pt
        df = DataFrame(pt["trial_events"])
        df[!, :id] .= pt["id"]
        df[!, :status] .= pt["status"]
        df[!, :sdma0] .= pt["sdma0"]
        df[!, :plt0] .= pt["plt0"]
        df[!, :runid] .= r.runid
        df[!, :skip_cday7] .= r.scenarios.SKIP_CDAY7
        df[!, :aegrade] .= ((plt,s) -> plt < s.PLT_G4 ? 4 :
            plt < s.PLT_G3 ? 3 :
            plt < s.PLT_G2 ? 2 :
            plt < 100 ? 1 : # FIXME: shouldn't be hard coded, should be provided in scenario
            0
        ).(df.plt, Ref(r.scenarios))

        return df
    end
    
    # will ultimately return a single combined dataframe of trial events
    return reduce(vcat, tev)

end;

#* new df of combined trial_events from all simulations in mysims
events = reduce(vcat, mysims.trial_events);

# convert runid to categorical value for use in summaries
events[!, :runlabel] = categorical(events.runid);
#? why can't this be converted in place
#//recode!(events.runlabel, 1=>"BLREF",2=>"EARLY6MG",3=>"ADJ4MG",4=>"PUB4MG",5=>"PUB6MG",6=>"PUB8MG")
events[!, :runlabel] = recode(events.runlabel,  [Pair(r.runid,r.labels) for r in eachrow(mysims)]...);

# reorganize columns
select!(
    events,
    :id, :runlabel, :status, :cycle, :day, 
    :cycle_day, :current_dose_dur, :cur_dose, :new_dose, 
    :sdma0, :sdma, :plt0, :plt, 
    :aegrade, :statdc, :interrupt, :skip_cday7, 
    :runid
);


##################################################################
#* Subjects on study by cycle and scenario
##################################################################
#* Reasonable to assume number of patients enrolled during each cycle will differ between scenarios
@info "Subjects on study by cycle and scenario"
@chain events begin
    select(:id, :runlabel, :cycle)
    unique(_)
    combine(groupby(_, [:runlabel, :cycle]), nrow => :enrolled)
    transform(groupby(_, :runlabel), :enrolled => (e -> first(e)) => :N)
    transform(groupby(_, :runlabel), :enrolled => (e -> 100*(e./first(e))) => :pct)
    transform([:enrolled,:N,:pct] => ByRow((e,n,p) -> "$p% ($e/$n)") => :value)
    select(:runlabel, :cycle, :value)
    unstack(_, :runlabel, :value)
    @aside CSV.write(joinpath("results",OUTDIR,"subjects_on_study.csv"), _)
    println
end

#=
#* Number of subjects with obs in C2 for BLREF and EARLY6MG is the same but referring back to the table
#* of observations by cycle there are fewer obs in C2 for the same number of patients. This suggests that
#* Early evaluation isn't improving safety, it's just shifting the point at which some patients exit the trial
=#

##################################################################
#* PD response over time
##################################################################
# ids for any patient that experienced a safety interrupt at any point
idsnointerrupts = @chain events begin
    transform(groupby(_, [:runlabel, :id]), [:interrupt] => maximum ∘ cumsum => :ninterrupts)
    select(:runlabel, :id, :ninterrupts)
    unique
end;

plotdf = @chain profiles begin
    filter(df -> df.evid == 0, _)
    innerjoin(
        _,
        idsnointerrupts,
        on = [:runlabel, :id]
    )
    transform(:ninterrupts => ByRow(n -> ifelse(n == 0, 1, 0)) => :nointerrupts)
    transform(:time => (w -> w ./ 168) => :week)
    combine(groupby(_, [:runlabel, :nointerrupts, :week]), [:plt, :sdma] .=> mean)
    stack([:plt_mean, :sdma_mean], variable_name = :endpoint, value_name = :response)
    transform([:nointerrupts, :endpoint] .=> categorical; renamecols = false)
end


plt = data(plotdf) * 
    mapping(
        :week => "Time (Weeks)",
        :response => "Response";
        color = :runlabel => "",
        linestyle = :runlabel => "",
        col = :nointerrupts => renamer(0 => "Interrupts", 1 => "No Interrupts"),
        row = :endpoint => renamer("plt_mean" => "Platelet (10⁹/L)", "sdma_mean" => "SDMA (ng/mL)")) *
    visual(Lines; linewidth = 3, linetype = :runlabel)

#? These options are repeated A LOT; can this be included as a theme to cut down on repetition
fig = draw(
    plt;
    figure = (;
        resolution = (1000,1000),
        fontsize = 20,
        colgap = 10
    ),
    axis = (;
        xticks = 0:4:16,
        ylabelfont = "TeX Gyre Heros Bold Makie",
        xlabelfont = "TeX Gyre Heros Bold Makie",
        #title = "Mean SDMA over time by scenario",
        #titlealign = :left,
        #titlesize = 26
    ),
    legend = (;
        position = :bottom,
        titleposition = :left,
        framevisible = false,
        padding = 0
    ),
    palettes = (;
        color = cgrad(:seaborn_colorblind, 5, categorical = true)
    )
)

# save current figure
save(joinpath("results",OUTDIR, "pd_over_time.png"), fig)

##################################################################
#* Proportion of patients experiencing CIT at any point by cycle and grade 
##################################################################
@info "Proportion of patients experiencing CIT at any point by cycle and grade"
@chain events begin
    transform(groupby(_, :runlabel), :id => length ∘ unique => :N)
    filter(df -> df.cycle_day ∈ [14,28] || (df.cycle_day == 7 && df.skip_cday7 == false), _)
    transform(:plt => ByRow(p -> ifelse(p < 100, 1, 0)) => :islt100)
    transform(groupby(_, [:runlabel, :id]), :islt100 => maximum => :iscit)
    combine(groupby(_, [:runlabel, :id]), first)
    combine(groupby(_, :runlabel), :N => Int ∘ mean => :N, :iscit => sum => :iscit)
    transform([:iscit, :N] => ByRow((np,n) -> "$(round(100*(np/n), digits =1))% ($np/$n)") => :pct)
    select(:runlabel, :pct)
    @aside CSV.write(joinpath("results",OUTDIR,"patients.csv"), _)
    println
end


##################################################################
#* Incidence of AEs by Cycle and Grade - BARPLOT
##################################################################

# FIXME: Early eval means an extra event which is artificially increasing the percentage for EARLY6MG and ADJ4MG
plotdf = @chain events begin
    filter(df -> df.cycle_day ∈ [14,28] || (df.cycle_day == 7 && df.skip_cday7 == false), _)
    combine(groupby(_, [:runlabel, :cycle, :aegrade]), nrow => :nevents)
    transform(groupby(_, :runlabel), :nevents => (n -> 100*(n ./ sum(n))) => :pct)
    #unstack(_, :runlabel, :nevents)
end

# TODO: Add total number of events at top of cols
plt = data(plotdf) *
mapping(:cycle => "Cycle", :pct => "Percent (%)"; color = :aegrade => nonnumeric => "AE Grade", col = :runlabel) *
visual(BarPlot;)

fig = draw(
    plt;
    figure = (;
        resolution = (1000,1000),
        fontsize = 20,
        colgap = 10
    ),
    axis = (;
        #xticks = [0,12,24,36,52,76,104],
        ylabelfont = "TeX Gyre Heros Bold Makie",
        xlabelfont = "TeX Gyre Heros Bold Makie",
        #title = "Mean SDMA over time by scenario",
        titlealign = :left,
        titlesize = 26
    ),
    legend = (;
        position = :bottom,
        titleposition = :left,
        framevisible = false,
        padding = 0
    ),
    palettes = (;
        color = cgrad(:seaborn_colorblind, 5, categorical = true)
    )
)

# save current figure
save(joinpath("results",OUTDIR, "incidence_cit_barplot.png"), fig)

##################################################################
#* Incidence of AEs by Cycle and Grade - RAINCLOUD
##################################################################

#* helper function for CIT raincloud
#* used helper because need to make 3 separate plots; 1 for Grades 1-3
function plot_cit_distribution(plotdata, obs, aegrade)
    plotdf = subset(plotdata, obs => x -> x .> 0)

    f = Figure(
        resolution = (1000,1000),
        fontsize = 20,
        colgap = 10
    )

    colors = cgrad(:seaborn_colorblind, 5, categorical = true);

    a = Axis(
        f[1,1], 
        ylabel = "Proportion of Time at or below Grade $aegrade CIT",
        ylabelfont = "TeX Gyre Heros Bold Makie",
        xticklabelfont = "TeX Gyre Heros Bold Makie",
        title = "Overall Time Spent in CIT",
        titlesize = 26,
        titlealign = :left
    )

    rainclouds!(a, string.(plotdf.runlabel), plotdf[!, obs]; color = colors[levelcode.(plotdf.runlabel)], clouds = nothing, markersize =4)

    return f

end;

plotdf = @chain events begin
    filter(df -> df.cycle_day ∈ [14,28] || (df.cycle_day == 7 && df.skip_cday7 == false), _)
    transform(:plt => ByRow(p -> ifelse(p < 50, 1, 0)) => :islt50)
    transform(:plt => ByRow(p -> ifelse(p < 75, 1, 0)) => :islt75)
    transform(:plt => ByRow(p -> ifelse(p < 100, 1, 0)) => :islt100)
    combine(groupby(_, [:runlabel, :id]), [:islt50, :islt75, :islt100] .=> mean .=> [:timeg3, :timeg2, :timeg1])
end

# display and save each of 3 CIT raincloud plots
for (i,j) in enumerate([:timeg1, :timeg2, :timeg3])
    fig = plot_cit_distribution(plotdf, j, i)
    display(fig)
    save(joinpath("results",OUTDIR, "incidence_g$(i)cit_raincloud.png"), fig)
end


##################################################################
#* Percentage of Subjects with G3 CIT - Any Cycle
##################################################################
#* this is very specific because G3 is where interrupts normally happen and the requirement
#* for restarting therapy
@info "Percentage of Subjects with G3 CIT - Any Cycle"
@chain events begin
    filter(df -> df.cycle_day ∈ [14,28] || (df.cycle_day == 7 && df.skip_cday7 == false), _)
    transform(groupby(_, [:runlabel]), :id => length ∘ unique => :N)
    filter(df -> df.interrupt, _)
    combine(groupby(_, [:runlabel, :id]), first)
    combine(groupby(_, [:runlabel]), :N => Int ∘ mean => :N, :interrupt => sum => :npatients)
    transform([:npatients, :N] => ByRow((np,n) -> "$(round(100*(np/n), digits =1))% ($np/$n)") => :pct)
    select(:runlabel, :pct)
    @aside CSV.write(joinpath("results",OUTDIR,"subjects_g3cit.csv"), _)
    println
end

##################################################################
#* Average Recovery Time for G3 Event
##################################################################
plotdf = @chain events begin
    transform([:cur_dose, :new_dose, :interrupt] => ByRow((c,n,i) -> ifelse(i && c > 0 && n == 0, 1, 0)) => :interruptstart)
    transform(groupby(_, :runlabel), :interruptstart => cumsum => :interruptgroup)
    filter(df -> df.interrupt, _)
    combine(groupby(_, [:runlabel, :interruptgroup]), nrow => :nweeks)
    combine(groupby(_, [:runlabel, :nweeks]), nrow => :ninterrupts)
    transform(groupby(_, :runlabel), [:ninterrupts] => (n -> 100*(n ./ sum(n))) => :pct)
end

plt = data(plotdf) *
mapping(:runlabel => "Scenario", :pct => "Percent (%)"; color = :nweeks => nonnumeric => "Recovery Time (Weeks)", dodge = :nweeks => nonnumeric => "") *
visual(BarPlot)

fig = draw(
    plt;
    figure = (;
        resolution = (1000,1000),
        fontsize = 20,
        colgap = 10
    ),
    axis = (;
        #xticks = [0,12,24,36,52,76,104],
        ylabelfont = "TeX Gyre Heros Bold Makie",
        xlabelfont = "TeX Gyre Heros Bold Makie",
        #title = "Mean SDMA over time by scenario",
        titlealign = :left,
        titlesize = 26
    ),
    legend = (;
        position = :bottom,
        titleposition = :left,
        framevisible = false,
        padding = 0
    ),
    palettes = (;
        color = cgrad(:seaborn_colorblind, 5, categorical = true)
    )
)

# save current figure
save(joinpath("results",OUTDIR, "recovery_time_g3cit.png"), fig)

##################################################################
#* Percentage of subjects Experiencing G4 CIT
##################################################################
#* note that this also describes the number of patients removed from the study in a given cycle
@info "Percentage of subjects experiencing G4 CIT"
@chain events begin
    transform(groupby(_, :runlabel), :id => length ∘ unique => :N)
    filter(df -> df.statdc, _)
    combine(groupby(_, [:runlabel, :cycle]), :N => identity => :N, nrow => :npatients)
    unique(_)
    transform([:npatients, :N] => ByRow((np,n) -> "$(round(100*(np/n), digits =1))% ($np/$n)") => :pct)
    select(:runlabel, :cycle, :pct)
    unstack(_, :runlabel, :pct)
    @aside CSV.write(joinpath("results",OUTDIR,"subjects_g4cit.csv"), _)
    println
end


##################################################################
#* Percentage of subjects with ≥78% Reduction in SDMA from BL
##################################################################
plotdf = @chain events begin
    filter(df -> df.cycle_day == 28, _)
    transform([:sdma,:sdma0] => ByRow((s,bl) -> (1 - (s/bl))*100) => :efficacy)
    transform(:efficacy => ByRow(e -> ifelse(e ≥ 78, 1, 0)) => :isge78)
    combine(groupby(_, [:runlabel, :cycle]), nrow => :npatients, :isge78 => mean => :responders)
    transform(:responders => ByRow(r -> r*100); renamecols = false)
end

plt = data(plotdf) *
mapping(:cycle => nonnumeric => "Cycle", :responders => "% Patients"; color = :runlabel => "", linestyle = :runlabel => "") *
visual(Lines; linewidth = 3)

fig = draw(
    plt;
    figure = (;
        resolution = (1000,1000),
        fontsize = 20,
        colgap = 10
    ),
    axis = (;
        #xticks = [0,12,24,36,52,76,104],
        ylabelfont = "TeX Gyre Heros Bold Makie",
        xlabelfont = "TeX Gyre Heros Bold Makie",
        title = "Target Attainment at Cycle Day 28",
        titlealign = :left,
        titlesize = 26
    ),
    legend = (;
        position = :bottom,
        titleposition = :left,
        framevisible = false,
        padding = 0
    ),
    palettes = (;
        color = cgrad(:seaborn_colorblind, 5, categorical = true)
    )
)

# save current figure
save(joinpath("results",OUTDIR, "subjects_at_sdma_target.png"), fig)

##################################################################
#*  Achievement of SDMA target by cycle and scenario
##################################################################

tbl = @chain events begin
    transform(groupby(_, :runlabel), :id => length ∘ unique => :N)
    filter(df -> df.cycle_day == 28, _)
    transform([:sdma,:sdma0] => ByRow((s,bl) -> (1 - (s/bl))*100) => :efficacy)
    transform(:efficacy => ByRow(e -> ifelse(e ≥ 78, 1, 0)) => :isge78)
    filter(df -> df.isge78 == 1, _)
    combine(groupby(_, [:runlabel, :id]), first)
    combine(groupby(_, [:runlabel, :cycle]), :N => Int ∘ mean => :N, nrow => :npatients)
    transform(groupby(_, :runlabel), [:N, :npatients] => ((n,p) -> n .- sum(p)) => :NR)
    transform(groupby(_, :runlabel), [:N, :npatients] => ((n,p) -> 100*(p./n)) => :pct_resp)
    transform(groupby(_, :runlabel), [:N, :NR] => ((n,nr) -> 100*(nr./n)) => :pct_nonresp)
    transform([:npatients,:N,:pct_resp] => ByRow((p,n,pr) -> "$(round(pr, digits =1))% ($p/$n)") => :responders)
    transform([:NR,:N,:pct_nonresp] => ByRow((nr,n,pnr) -> "$(round(pnr, digits =1))% ($nr/$n)") => :nonresponders)
end;

responders = @chain tbl begin
    select(:runlabel, :cycle, :responders)
    unstack(:runlabel, :responders)
    transform(:cycle => (c -> string.(c)); renamecols = false)
end;

nonresponders = @chain tbl begin
    select(:runlabel, :cycle, :nonresponders)
    combine(groupby(_, :runlabel), first)
    unstack(:runlabel, :nonresponders)
    transform(:cycle => (c -> "NR"); renamecols = false)
end;

@info "Achievement of SDMA target by cycle and scenario"
finaltbl = vcat(responders, nonresponders)
finaltbl
# save table
CSV.write(joinpath("results",OUTDIR, "sdma_target_by_scenario.csv"), finaltbl)

##################################################################
#* Summary of number of cycles at SDMA target by scenario
##################################################################
@info "Summary of number of cycles at SDMA target by scenario"
@chain events begin
    transform(groupby(_, :runlabel), :id => length ∘ unique => :N)
    filter(df -> df.cycle_day == 28, _)
    transform([:sdma,:sdma0] => ByRow((s,bl) -> (1 - (s/bl))*100) => :efficacy)
    transform(:efficacy => ByRow(e -> ifelse(e ≥ 78, 1, 0)) => :isge78)
    combine(groupby(_, [:runlabel, :id]), :N => Int ∘ mean => :N, :isge78 => sum => :cyclesatgoal)
    combine(groupby(_, [:runlabel, :cyclesatgoal]), :N => Int ∘ mean => :N, nrow => :npatients)
    transform(groupby(_, :runlabel), :npatients => sum => :N28)
    transform([:cyclesatgoal, :N, :npatients, :N28] => ByRow((c,n,np,n28) -> ifelse(c == 0, np+(n-n28), np)) => :npatients)
    transform([:npatients,:N] => ByRow((np,n) -> "$(round(100*(np/n), digits =1))% ($np/$n)") => :pct)
    select(:runlabel, :cyclesatgoal, :pct)
    unstack(_, :runlabel, :pct)
    @aside CSV.write(joinpath(OUTDIR,"cycles_at_goal.csv"), _)
    println
end


##################################################################
#* Time Above Target Reduction
##################################################################

plotdf = @chain profiles begin
    filter(df -> df.evid == 0, _)
    transform([:sdma,:sdma0] => ByRow((s,bl) -> (1 - (s/bl))*100) => :efficacy)
    transform(:efficacy => ByRow(e -> ifelse(e ≥ 78, 1, 0)) => :isge78)
    combine(groupby(_, [:runlabel, :id]), :isge78 => mean => :timeabovegoal)
end

f = Figure(
    resolution = (1000,1000),
    fontsize = 20,
    colgap = 10
)

a = Axis(
    f[1,1], 
    ylabel = "Proportion of Time SDMA Reduction Above Target",
    ylabelfont = "TeX Gyre Heros Bold Makie",
    xticklabelfont = "TeX Gyre Heros Bold Makie",
    title = "Durability of SDMA Repsonse",
    titlesize = 26,
    titlealign = :left
)
colors = cgrad(:seaborn_colorblind, 5, categorical = true)
rainclouds!(a, string.(plotdf.runlabel), plotdf.timeabovegoal; color = colors[levelcode.(plotdf.runlabel)])

# save current figure
save(joinpath("results",OUTDIR, "time_above_target.png"), f)


##################################################################
#* Distribution of Doses Per Cycle
##################################################################

plotdf = @chain events begin
    filter(df -> df.cycle_day == 28 || (df.cycle == 1 && df.cycle_day == 0), _)
    transform([:cycle, :cycle_day] => ByRow((c,d) -> ifelse(c==1 && d==0, c-1, c)) => :cycle)
    combine(groupby(_, [:runlabel, :cycle, :new_dose]), :new_dose => (d -> length(d)) => :nobs)
    transform(groupby(_, [:runlabel, :cycle]), :nobs => (n -> 100* n ./ sum(n)) => :pct)
end

plt = data(plotdf) *
    mapping(:cycle => "Cycle", :pct => "Percent (%)"; color = :new_dose => nonnumeric => "", layout = :runlabel) *
    visual(Lines; linewidth = 3)

# FIXME this causes an extra empty axis to be added to the plot
#plt_hlines = mapping([25, 75]) * visual(HLines; color = (:black, 0.5), linestyle = :dash)

fig = draw(
    plt; # + plt_hlines;
    figure = (;
        resolution = (1000,1000),
        fontsize = 20,
        colgap = 10
    ),
    axis = (;
        #xticks = [0,12,24,36,52,76,104],
        ylabelfont = "TeX Gyre Heros Bold Makie",
        xlabelfont = "TeX Gyre Heros Bold Makie",
        #title = "Mean PLT over time by scenario",
        titlealign = :left,
        titlesize = 26
    ),
    legend = (;
        position = :bottom,
        titleposition = :left,
        framevisible = false,
        padding = 0
    ),
    palettes = (;
        color = cgrad(:seaborn_colorblind, 5, categorical = true)
    )
)

# save current figure
save(joinpath("results",OUTDIR, "dose_distribution_by_cycle.png"), fig)



