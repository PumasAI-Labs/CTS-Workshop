##################################################################
#* Load Packages
##################################################################
@info "Load Packages"
using Distributed
@everywhere using Pumas
@everywhere using Serialization, StableRNGs, Random, StatsBase
@everywhere using DataFramesMeta, CSV, Dates, ShiftedArrays, CategoricalArrays
@everywhere using CairoMakie, AlgebraOfGraphics

##################################################################
# Description
##################################################################
#=

=#

##################################################################
# Output Variables
##################################################################
result_filename = tempname() * ".jls"
@info result_filename
ENV["RESULTS_FILE"] = result_filename

##################################################################
#* Define Scenarios
##################################################################
@info "Define Scenarios"
# baseline reference; 6 mg PO q24h with dose adjustment based on safety/efficacy
ADJ6MG = (
    NO_DOSE_ADJ = false, # disable dose adjustment logic and simulate all cycles at 1 dose
    SKIP_CDAY7 = true, # skip "visit" on cycle day 7
    G2_ADJUST = false, # allow dose adjustment based on Grade 2 thrombocytopenia
    PLT_G4 = 25, # threshold for Grade 4 thrombocytopenia
    PLT_G3 = 50, # threshold for G3 thrombocytopenia
    PLT_G2 = 75, # threshold for G2 thrombocytopenia
    RESP_VARS = (SDMA = :sdma, PLT = :plt), # PD response variables
    EFF_TARGET = 78, # efficacy target; default is 78% reduction in SDMA from baseline
    EFF_TARGET_OFFSET = 0, # % reduction in efficacy target (0 = none); makes multiple dose increases more difficult 
    RECHECK_SCHED = 7, # days between scheduled evaluations of PLT
    INIT_REG = (AMT = 6.0, TIME = 0, II = 24, ADDL = 6), # initial regimen given to all patients; ADDL = 6 (daily dosing, weekly observations)
    COVARIATES = Symbol[], # vector of symbols for cols containing cov values, empty because no covariates
    REPRODUCIBLE = true, # flag for whether seed should be set to make sim results reproducible
);

##################################################################
#* Import Model(s)
##################################################################
@info "Load Combined PKPD Model"
# import ntp that always includes model (mdl) and can include optional param sets
@everywhere combined_pkpd = include("./models/combined_pkpd.jl");

##################################################################
#* Import Final Parameter Estimates
##################################################################
@info "Load Final Parameter Estimates"
#* Params must be passed as a NamedTuple, CSV.read returns a df
#* Tables.rowtable() returns a vector of NamedTuples
#* Because there's a single row, [begin] will gives us the ntp we need
@everywhere final_estimates = Tables.rowtable(CSV.read(joinpath(@__DIR__, "final_estimates.csv"), DataFrame))[begin];

##################################################################
#* Load Simulation Functions and Data
##################################################################
@info "Load Simulation Functions"
# load simulation functions
@everywhere include("./utils/sim_functions.jl")


##################################################################
# Simulate Scenarios
##################################################################
@info "Load Simulation Dataset"
# Set number of subjects to simulate in each scenario
subjects_to_sim = 500;

# Set number of cycles
ncycles = 3;

# empty dataframe to sim info and results
mysims = DataFrame();

# tags that can used to identify each run later if desired
tags = [

];

# labels used when stratifying tables/plots by sim
labels = [

];

# scenarios to be used
scenarios = [

];

# add required columns to df
mysims[!, :runid] = 1:length(tags);
mysims[!, :tags] .= tags;
mysims[!, :labels] .= labels;
mysims[!, :models] .= Ref((; combined_pkpd));
mysims[!, :params] .= Ref(final_estimates)
mysims[!, :scenarios] .= scenarios;

# each row contains a df of N subjects_to_sim that will be used as input
# models and scenario get added to each row of the patients df in the map below
mysims[!, :patients] = map(eachrow(mysims)) do r
    df = DataFrame(id = collect(1:subjects_to_sim) .+ 10000)
    df[!, :models] .= Ref(r.models)
    df[!, :scenario] .= Ref(r.scenarios)
    df[!, :params] .= Ref(r.params)
    return df
end;

#* perform simulations
mysims[!, :sims] = pmap(eachrow(mysims)) do r
    map(eachrow(r.patients)) do subr
        try
            return sim_trial(subr, ncycles);
        catch e
            return e
        end
    end
end;

###################################################################
# Save Results
##################################################################
@info "Serialize Results"
open(result_filename, "w") do io
    serialize(io, mysims)
end
