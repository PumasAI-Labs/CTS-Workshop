##################################################################
#* Load Packages
##################################################################
using Pumas
using Serialization, StableRNGs, Random, StatsBase
using DataFramesMeta, ShiftedArrays, CategoricalArrays
using CairoMakie, AlgebraOfGraphics

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

##################################################################
#* Import Model(s)
##################################################################
# import ntp that always includes model (mdl) and can include optional param sets
combined_pkpd = include("template/models/combined_pkpd.jl");

##################################################################
#* Load Simulation Functions and Data
##################################################################
# load simulation functions
include("template/utils/sim_functions.jl")
final_estimates = Tables.rowtable(CSV.read(joinpath(@__DIR__, "final_estimates.csv"), DataFrame))[begin];
##################################################################
#* Single Test Patient
##################################################################

# sim_trial takes a DataFrameRow as its first positional argument
single_pt_df = DataFrame(id = 1);

# dataframe must contain models, scenario, and baseline covariates
single_pt_df[!, :models] .= Ref((; combined_pkpd)); #* Need Ref to prevent DataFrames.jl from expanding the ntp
single_pt_df[!, :scenario] .= Ref(ADJ6MG); #* same reason as above
single_pt_df[!, :params] .= Ref(final_params)

# sim 3 cycles for a single patient
single_pt = sim_trial(single_pt_df[1,:], 3);

#? What information can you gather by examining the Patient data returned from sim_trial?
single_pt

# review trial_events (ntp)
single_pt["trial_events"]

# somewhat difficult to read, what about a df?
single_pt["trial_events"] |> DataFrame

# review most recent profile (SimulatedObservations)
single_pt["profile"]

# convert to a df
single_pt["profile"] |> DataFrame

# way more columns than we need, but let's see what's available
single_pt["profile"] |> DataFrame |> vscodedisplay