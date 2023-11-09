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
# Import Model Fit Inspect Files
##################################################################
#* set directory where estimation results are stored
FITDIR = "estimation/fits/2023-11-09T12:51:47"

#! The order here matters, and must match the order of symbols in coreparams below
#! in the COREQPC section
inspectdfs = map(["pk","sdma","plt"]) do f
    CSV.read(joinpath(FITDIR,f,f*"_inspect.csv"), DataFrame; stringtype = String)
end;


##################################################################
# Helper Functions
##################################################################
function plot_qpc(repq50, q5, q50, q95, refvalue, xlab)

    f = Figure(
        resolution = (1000,1000),
        fontsize = 20
    )

    a = Axis(f[1,1]; xlabel = xlab)
    
    hist!(a, repq50, color = :gray, strokewidth = 1, strokecolor = :black)
    vlines!(a, [q5,q50,q95], color = :black, linestyle = :dash, linewidth = 3)
    vlines!(a, refvalue, color = :lightblue, linestyle = :dashdot, linewidth = 3)

    return f

end


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
# recode level labels based on labels used in each simulation scenario
profiles[!, :runlabel] = recode(profiles.runlabel, [Pair(r.runid,r.labels) for r in eachrow(mysims)]...);


##################################################################
# Qualification DataFrame
##################################################################

# dataframe with values for qualification
qualdf = @chain profiles begin
    filter(df -> df.evid == 0, _)
    filter(df -> df.time == 336, _)
    select(:id, :time, :dv, :sdma, :plt, :cl, :vc, :sdma0, :circ0, :slope)
    transform([:sdma, :sdma0] => ByRow((s,bl) -> 100*(1-(s/bl))) => :sdmaredbl)
end

# add repid for 200 reps, 50 subjects per rep
qualdf[!, :repid] = repeat(1:200, inner = 50);



##################################################################
# Core QPC 
##################################################################

#! order is PK, SDMA, PLT and MUST match the order in which inspect files were imported
coreparams = [
    [:cl, :vc],
    [:sdma0],
    [:circ0, :slope]
];

coreqpc = map(zip(inspectdfs, coreparams)) do (idf, param)

    # FIXME: this needs to be on a df of inspect else it will run inspect each time repeated; costly
    iparams = combine(groupby(idf, :id), first)

    qpcplots = map(param) do p

        # vector of median values for each repid for a given param (p)
        refq50 = combine(groupby(qualdf, :repid), p => (x -> quantile(x, 0.5)) => :q50).q50

        # refq50 quantiles
        q5 = quantile(refq50, 0.05)
        q50 = quantile(refq50, 0.50)
        q95 = quantile(refq50, 0.95)

        # median value from original fit
        refvalue = quantile(iparams[!,p], 0.5)

        plt = plot_qpc(refq50, q5, q50, q95, refvalue, "50th Percentile for "*uppercase(string(p)))

        try
            save(joinpath("results",OUTDIR,string(p)*"_qpc.png"), plt)
        catch e
            @info "Could not save $(string(p)) QPC plot"
        end

        return plt

    end

    return qpcplots

end

for p in reduce(vcat, coreqpc)
    display(p)
end

##################################################################
# Derived QPC
##################################################################
#* This section should be interpretted with caution because on 4 subjects
#* in the original dataset received 6mg PO q24h

#! input must be a vector or inner map() will fail
observedvals = [
    [:dv],
    [:sdma],
    [:plt]
];

derivedqpc = map(zip(inspectdfs, observedvals)) do (idf, val)

    # FIXME: this needs to be on a df of inspect else it will run inspect each time repeated; costly
    obsval = filter(df -> df.time == 336.001 && df.evid == 0 && df.tdd == 6 && df.freqn == 24, idf)

    qpcplots = map(val) do v

        # vector of median values for each repid for a given value (val)
        refq50 = combine(groupby(qualdf, :repid), v => (x -> quantile(x, 0.5)) => :q50).q50

        # refq50 quantiles
        q5 = quantile(refq50, 0.05)
        q50 = quantile(refq50, 0.50)
        q95 = quantile(refq50, 0.95)

        # median value from original fit
        refvalue = quantile(obsval[!,v], 0.5)

        plt = plot_qpc(refq50, q5, q50, q95, refvalue, "50th Percentile for "*uppercase(string(v)))

        try
            save(joinpath("results",OUTDIR,string(v)*"_qpc.png"), plt)
        catch e
            @info "Could not save $(string(v)) QPC plot"
        end

        return plt

    end

    return qpcplots

end

for p in reduce(vcat, derivedqpc)
    display(p)
end

##################################################################
# Endpoint QPC
##################################################################

obsval = filter(df -> df.time == 336.001 && df.evid == 0 && df.tdd == 6 && df.freqn == 24, inspectdfs[2])
transform!(obsval, [:sdma, :sdma0] => ByRow((s,bl) -> 100*(1-(s/bl))) => :sdmaredbl)

# vector of median values for each repid for a given param (p)
refq50 = combine(groupby(qualdf, :repid), :sdmaredbl => (x -> quantile(x, 0.5)) => :q50).q50

# refq50 quantiles
q5 = quantile(refq50, 0.05)
q50 = quantile(refq50, 0.50)
q95 = quantile(refq50, 0.95)

# median value from original fit
refvalue = quantile(obsval[!,:sdmaredbl], 0.5)

plt = plot_qpc(refq50, q5, q50, q95, refvalue, "50th Percentile for SDMA Reduction from BL")

# show current figure
current_figure()

# attempt to save current figure
try
    save(joinpath("results",OUTDIR,"sdmaredbl_qpc.png"), plt)
catch e
    @info "Could not save SDMA reduction QPC plot"
end
