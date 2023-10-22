##################################################################
# Load Packages
##################################################################
using Serialization
using DataFramesMeta, ShiftedArrays, CategoricalArrays
using CairoMakie, AlgebraOfGraphics

##################################################################
# Helper Functions
##################################################################


##################################################################
# Explore Structure of Results
##################################################################
# final df
mysims

# each row of sims contains an array of 5000 patients
mysims.sims[1] #* first set of 5000
mysims.sims[1][1] #* first patient from first set

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
        df[!, :skip_cday7] .= r.scenario.SKIP_CDAY7
        return df
    end
    
    # will ultimately return a single combined dataframe of trial events
    return reduce(vcat, tev)

end;

#* new df of combined trial_events from all simulations in mysims
events = reduce(vcat, mysims.trial_events);

# convert runid to categorical value for use in summaries
events[!, :runlabel] = categorical(events.runid)
#? why can't this be converted in place
#//recode!(events.runlabel, 1=>"BLREF",2=>"EARLY6MG",3=>"ADJ4MG",4=>"PUB4MG",5=>"PUB6MG",6=>"PUB8MG")
events[!, :runlabel] = recode(events.runlabel, 1=>"BLREF",2=>"EARLY6MG",3=>"ADJ4MG",4=>"PUB4MG",5=>"PUB6MG",6=>"PUB8MG");

# reorganize columns
select!(events, :id, :runlabel, :status, :cycle, :day, :cycle_day, :current_dose_dur, :cur_dose, :new_dose, :sdma0, :sdma, :plt0, :plt, :statdc, :interrupt, :skip_cday7, :runid)

##################################################################
# Observations per Scenario by Cycle
##################################################################

#* Reasonable assumption given different scenarios that the number of obs per scenario will differ between cycles
# observations per cycle by scenario
@chain events begin
    filter(df -> df.runid ≤ 3, _)
    combine(groupby(_, [:runlabel, :cycle]), nrow => :nobs)
    unstack(_, :cycle, :nobs)
end

#* small helper function to compare dataframes
#! only works if all columns are numbers or can be converted to numbers 
function compare_dfs(df1, df2)
    #select!(df1, :cycle, :day, :cycle_day, All())
    #select!(df2, :cycle, :day, :cycle_day, All())
    if df1 == df2
        return true
    else  
        return isapprox.(df1,df2)
    end
end

#? is cycle 1 the same for runids 1 and 2 (excluding cols that are categorical or known to differ by definition)
compare_dfs(
    select(filter(df -> df.runid == 1 && df.cycle == 1, events), Not([:runlabel,:skip_cday7,:runid])),
    select(filter(df -> df.runid == 2 && df.cycle == 1, events), Not([:runlabel,:skip_cday7,:runid]))    
)

#* implies that early safety eval doesn't help in cycle 1, confirm no PLT <50 in BLREF cycle 1
@chain events begin
    filter(df -> df.runid == 1, _)
    filter(df -> df.cycle == 1 && df.cycle_day == 7, _)
    filter(df -> df.plt < 50, _)
end

##################################################################
# Subjects Enrolled Per Scenario by Cycle
##################################################################

#* Reasonable to assume number of patients enrolled during each cycle will differ between scenarios
@chain events begin
    filter(df -> df.runid ≤ 3, _)
    select(:id, :runlabel, :cycle)
    unique(_)
    combine(groupby(_, [:runlabel, :cycle]), nrow => :enrolled)
    unstack(_, :cycle, :enrolled)
end

#=
#* Number of subjects with obs in C2 for BLREF and EARLY6MG is the same but referring back to the table
#* of observations by cycle there are fewer obs in C2 for the same number of patients. This suggests that
#* Early evaluation isn't improving safety, it's just shifting the point at which some patients exit the trial
=#

##################################################################
# Percentage of Patients with G3 COT
##################################################################

@chain events begin
    filter(df -> df.runid ≤ 3, _)
    filter(df -> df.cycle_day ∈ [14,28] || (df.cycle_day == 7 && df.skip_cday7 == false), _)
end

events