##################################################################
# Load Packages
##################################################################
using Pumas
using DataFramesMeta, Serialization

##################################################################
# Trial Reference
##################################################################
#=
PK Sampling
Cycle 1
    Day 1: 0, 0.5, 1, 2, 4, 6, and 12 (bid) or 24 (qD)
    Day 8: Pre-dose
    Day 15: 0, 0.5, 1, 2, 4, 6 and 12 (bid) or 24 (qD)
    Day 22: Pre-dose
Remaining Cycles
    Day 1: Pre-dose

SDMA
Cycle 1
    Day 1: 0, 2, 6, and 12 (bid) or 24 (qD)
    Day 8: Pre-dose
    Day 15: 0, 2, 6, and 12 (bid) or 24 (qD)
    Day 22: Pre-dose
Remaining Cycles
    Day 1: Predose

Hematology
Cycle 1
    Day 1, 8, 15, 22: Pre-dose
Remaining Cycles
    Day 1, 15: Pre-dose


Demographics
Age 63 (33, 85) median (min,max) <--- add and use a numerical
TBW 89 (55, 137)

Sex (M:F), 15:13 <--- add and use character instead of numeric
Race (1:5), 3:25; 1=AA, 5=white
Liver function (1:2), 24:4; 1=normal, 2=mild impairment
ECOG PS (0:1), 6:22;  
=#

##################################################################
# Define dosing groups
##################################################################

# vector of tuples with details about number of subjects per dosing group and frequency
# using this format makes the information concise/legible and it can easily be expanded
# to a vector containing all (28) subjects
# n = number of subjects in group
# dose = pf06 dose in mg
# ii = dosing frequency in hours
dosing_groups = [
    (n = 1, dose = 0.5, ii = 12),
    (n = 5, dose = 4, ii = 12),
    (n = 6, dose = 6, ii = 12),
    (n = 3, dose = 8, ii = 12),
    (n = 1, dose = 0.5, ii = 24),
    (n = 2, dose = 1, ii = 24),
    (n = 3, dose = 2, ii = 24),
    (n = 3, dose = 4, ii = 24),
    (n = 4, dose = 6, ii = 24)
];

##################################################################
# Expand dosing groups and create Population
##################################################################

# vector with one line per subject by dosing group
# comprehension used to expand each element of dosing_group
# reduce(vcat, ...) returns a single vector of subject info
all_subjects = reduce(vcat, [fill(x, x.n) for x in dosing_groups])

# Population based on elements of all_subjects (vector of Subjects = Population)
# enumerate used to easily assign each patient an numerical id
mypop = map(enumerate(all_subjects)) do (i, j)
    Subject(
        id = i,
        # dose mg -> μg; addl = (ncycles * days/cycle * (24/ii))-1; ncycles = 3
        events = DosageRegimen(j.dose*1000, time=0, ii = j.ii, addl = (3*28*(24/j.ii))-1),
        covariates = (tdd = j.dose*(24/j.ii), freqn = j.ii),
        #TODO: confirm whether cov_dir is needed
        covariates_direction = :right 
    )
end


##################################################################
# Define Samples Times
##################################################################

# helper function for defining sampling times
# will assume max number of observations which is more info than was available
# in the original trial, but it's easier prune data after initial sim

function get_full_schedule(ncycles)

    #* note the use of 0.001 instead of 0
    serial_times= [0.001,0.5,1,2,4,6,12,24]
    predose = [0.001]

    schedule = map(1:ncycles) do cycle

        if cycle == 1
            d1 = serial_times
            d8 = predose .+ (24*8)
            d15 = serial_times .+ (24*15)
            d22 = predose .+ (24*22)
            [d1; d8; d15; d22]
        else
            d1 = predose .+ ((((cycle-1)*28)+1)*24)
            d15 = predose .+ ((((cycle-1)*28)+16)*24)
            [d1; d15]
        end
        
    end

    return sort!(reduce(vcat, schedule))

end
 

##################################################################
# Import combined model and simulate trial
##################################################################

# runs the contents of combined_pkpd_ref.jl which is a NamedTuple of the combined (PK, SDMA, PLT)
# model provided in the reference supplement. Using a ntp allows you to include multiple
# param sets in a single model file and load them as needed
combined_mdl = include("combined_pkpd_ref.jl").mdl

# TODO: add RNG

# simulate observations
mysim = simobs(
    combined_mdl,
    mypop,
    init_params(combined_mdl),
    obstimes = get_full_schedule(3) # 3 cycles
)

##################################################################
# Prune sampling times
##################################################################

# function will return a ntp with keys for pk, sdma, and plt
# each key holds a vector of times that approximates the original trial
function get_pruned_schedule(ncycles, ii)
    #* note the use of 0.001 instead of 0
    predose = [0.001]
    pk_times = [0.001,0.5,1,2,4,6,ii]
    sdma_times = [0.001,2,6,ii]

    pk = map(1:ncycles) do cycle

        if cycle == 1
            d1 = pk_times
            d8 = predose .+ (24*8)
            d15 = pk_times .+ (24*15)
            d22 = predose .+ (24*22)
            [d1; d8; d15; d22]
        else
            d1 = predose .+ ((((cycle-1)*28)+1)*24)
        end

    end

    pk = sort(reduce(vcat, pk))

    sdma = map(1:ncycles) do cycle

        if cycle == 1
            d1 = sdma_times
            d8 = predose .+ (24*8)
            d15 = sdma_times .+ (24*15)
            d22 = predose .+ (24*22)
            [d1; d8; d15; d22]
        else
            d1 = predose .+ ((((cycle-1)*28)+1)*24)
        end

    end

    sdma = sort(reduce(vcat, sdma))

    plt = map(1:ncycles) do cycle

        if cycle == 1
            d1 = predose
            d8 = predose .+ (24*8)
            d15 = predose .+ (24*15)
            d22 = predose .+ (24*22)
            [d1; d8; d15; d22]
        else
            d1 = predose .+ ((((cycle-1)*28)+1)*24)
            d15 = predose .+ ((((cycle-1)*28)+16)*24)
            [d1; d15]
        end

    end

    plt = sort(reduce(vcat, plt))

    return (; pk, sdma, plt)

end

# get "pruned" schedules for both q12h and q24h dosing
pruned_q12h = get_pruned_schedule(3, 12)
pruned_q24h = get_pruned_schedule(3, 24)

# store results of sim in a dataframe to manipulate times
mydf = DataFrame(mysim)

# for each row in mydf, check each observation column against the appropriate
# element of the pruned schedule ntp and set all values not in the original
# sampling scheme to missing.
for dfr in eachrow(mydf)

    if dfr.freqn == 12
        dfr.dv = dfr.time ∈ pruned_q12h.pk ? dfr.dv : missing
        dfr.sdma = dfr.time ∈ pruned_q12h.sdma ? dfr.sdma : missing
        dfr.plt = dfr.time ∈ pruned_q12h.plt ? dfr.plt : missing
    else
        dfr.dv = dfr.time ∈ pruned_q24h.pk ? dfr.dv : missing
        dfr.sdma = dfr.time ∈ pruned_q24h.sdma ? dfr.sdma : missing
        dfr.plt = dfr.time ∈ pruned_q24h.plt ? dfr.plt : missing
    end

end

# confirm that number of observations is similar to original trial (pk: 400, sdma: 247, plt: 221)
describe(mydf, :min, :max, :nnonmissing; cols = [:dv, :sdma, :plt])

# find any rows where evid = 0 and all of the observation columns have missing values (should = 0)
filter(df -> df.evid == 0 && all(ismissing, df[Cols(:dv, :sdma, :plt)]), mydf)

# remove the above rows
filter!(df -> !(df.evid == 0 && all(ismissing, df[Cols(:dv, :sdma, :plt)])), mydf)


##################################################################
# Correct dv=0 at t=0
##################################################################

# Pumas does not allow dv values of 0 at time=0, they must be set to missing
#transform(mydf, [:time, :dv] => ByRow((t,d) -> ifelse(t == 0, missing, d)) => :dv)


##################################################################
# Export trial data
##################################################################
# drop extra cols and save trial data
# a word of warning about using .jls and serialization
@chain mydf begin
    select(:id, :evid, :time, :amt, :cmt, :dv, :sdma, :plt, :tdd, :freqn)
    serialize("data/trial_data.jls", _)
end
