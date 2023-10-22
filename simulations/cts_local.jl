##################################################################
#* Load Packages
##################################################################
using Pumas
using DataFramesMeta, Serialization, StableRNGs, Random

##################################################################
#* Define Scenarios
##################################################################
# baseline reference; 6 mg PO q24h with dose adjustment based on safety/efficacy
BLREF = (
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
);

# Early safety evaluation with immediate dose adjustment for G2 AE
EARLY6MG = (; BLREF..., SKIP_CDAY7 = false);

# Lower starting dose (4 mg PO q24h) with dose adjustment based on safety/efficacy
ADJ4MG = (; BLREF..., INIT_REG = (AMT = 4.0, TIME = 0, II = 24, ADDL = 6));

# published example, 4 mg PO q24h without opportunity for dose adjustment
NOADJ4MG = (; BLREF..., NO_DOSE_ADJ = true, INIT_REG = (AMT = 4.0, TIME = 0, II = 24, ADDL = 6));

# published example, 6 mg PO q24h without opportunity for dose adjustment
NOADJ6MG = (; BLREF..., NO_DOSE_ADJ = true, INIT_REG = (AMT = 6.0, TIME = 0, II = 24, ADDL = 6));

# published example, 8 mg PO q24h without opportunity for dose adjustment
NOADJ8MG = (; BLREF..., NO_DOSE_ADJ = true, INIT_REG = (AMT = 8.0, TIME = 0, II = 24, ADDL = 6));

##################################################################
#* Import Model(s)
##################################################################
# import ntp that always includes model (mdl) and can include optional param sets
combined_pkpd = include("models/combined_pkpd.jl");

##################################################################
#* Load Simulation Functions and Data
##################################################################
# load simulation functions
include("sim_functions.jl")

##################################################################
# Single Test Patient
##################################################################

# sim_trial takes a DataFrameRow as its first positional argument
single_pt_df = DataFrame(id = 1);

# dataframe must contain models, scenario, and baseline covariates
single_pt_df[!, :models] .= Ref((; combined_pkpd)); #* Need Ref to prevent DataFrames.jl from expanding the ntp
single_pt_df[!, :scenario] .= Ref(BLREF); #* same reason as above

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


##################################################################
# Multiple Scenarios (N=500)
##################################################################
# empty dataframe to sim info and results
mysims = DataFrame()

# tags that can used to identify each run later if desired
tags = [
    "adj_3c_cd1528_6mg",
    "adj_3c_cd71528_6mg",
    "adj_3c_cd1528_4mg",
    "noadj_3c_4mg",
    "noadj_3c_6mg",
    "noadj_3c_8mg",
];

# add required columns to df
mysims[!, :runid] = 1:length(tags);
mysims[!, :tags] .= tags;
mysims[!, :models] .= Ref((; combined_pkpd));
mysims[!, :scenarios] .= [BLREF,EARLY6MG,ADJ4MG,NOADJ4MG,NOADJ6MG,NOADJ8MG];

# each row contains a df of N patients that will be used as input
# models and scenario get added to each row of the patients df in the map below
# TODO: if time allows, use actual patient population with covariates and include import method
mysims[!, :patients] = map(eachrow(mysims)) do r
    df = DataFrame(id = collect(1:5000) .+ 10000)
    df[!, :models] .= Ref(r.models)
    df[!, :scenario] .= Ref(r.scenario)
    return df
end;

#* perform simulations
mysims[!, :sims] = map(eachrow(mysims)) do r
    map(eachrow(r.patients)) do subr
        return sim_trial(subr, 3);
    end
end;
