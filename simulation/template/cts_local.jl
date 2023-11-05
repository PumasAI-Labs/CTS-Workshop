##################################################################
#* Load Packages
##################################################################
using Pumas
using Serialization, StableRNGs, Random, StatsBase
using DataFramesMeta, Dates, ShiftedArrays, CategoricalArrays
using CairoMakie, AlgebraOfGraphics

##################################################################
# Description
##################################################################
#=

=#

##################################################################
#* Define Scenarios
##################################################################
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

# Early safety evaluation with immediate dose adjustment for G2 AE
EARLY6MG = (; ADJ6MG..., SKIP_CDAY7 = false);

# Lower starting dose (4 mg PO q24h) with dose adjustment based on safety/efficacy
ADJ4MG = (; ADJ6MG..., INIT_REG = (AMT = 4.0, TIME = 0, II = 24, ADDL = 6));

##################################################################
#* Import Model(s)
##################################################################
# import ntp that always includes model (mdl) and can include optional param sets
combined_pkpd = include("models/combined_pkpd.jl");

##################################################################
#* Load Simulation Functions and Data
##################################################################
# load simulation functions
include("utils/sim_functions.jl")


##################################################################
# Multiple Scenarios (N=500)
##################################################################
# empty dataframe to sim info and results
mysims = DataFrame()

# tags that can used to identify each run later if desired
tags = [
    "adj_3c_cd1528_6mg",
    "adj_3c_cd71528_6mg",
    "adj_3c_cd1528_4mg"
];

# labels used when stratifying tables/plots by sim
labels = [
    "ADJ6MG*",
    "EARLY6MG",
    "ADJ4MG"
];

# add required columns to df
mysims[!, :runid] = 1:length(tags);
mysims[!, :tags] .= tags;
mysims[!, :labels] .= labels;
mysims[!, :models] .= Ref((; combined_pkpd));
mysims[!, :scenarios] .= [ADJ6MG,EARLY6MG,ADJ4MG];

# each row contains a df of N patients that will be used as input
# models and scenario get added to each row of the patients df in the map below
# TODO: if time allows, use actual patient population with covariates and include import method
mysims[!, :patients] = map(eachrow(mysims)) do r
    df = DataFrame(id = collect(1:500) .+ 10000)
    df[!, :models] .= Ref(r.models)
    df[!, :scenario] .= Ref(r.scenarios)
    return df
end;

#* perform simulations
mysims[!, :sims] = map(eachrow(mysims)) do r
    map(eachrow(r.patients)) do subr
        return sim_trial(subr, 3);
    end
end;

###################################################################
# Save Results
##################################################################
# add serialized result to OUTDIR
serialize(joinpath("results", OUTDIR, "mysims.jls"), mysims)