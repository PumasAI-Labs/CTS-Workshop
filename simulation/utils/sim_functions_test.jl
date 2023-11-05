##################################################################
# Load Packages
##################################################################
using Pumas
using DataFramesMeta

##################################################################
# Helper Functions and Data
##################################################################

include("sim_functions.jl")

# FIXME: update this with the final sim combined model, not the ref
combined_pkpd = include("../setup/combined_pkpd_ref.jl")

SCENARIO = (
    NO_DOSE_ADJ = false, # disable dose adjustment logic and simulate all cycles at 1 dose
    SKIP_CDAY7 = false,
    G2_ADJUST = false,
    PLT_G4 = 25,
    PLT_G3 = 50,
    PLT_G2 = 75,
    RESP_VARS = (SDMA = :sdma, PLT = :plt), # :sdma
    EFF_TARGET = 78, # 78% reduction in SDMA from baseline
    EFF_TARGET_OFFSET = 0, # % reduction in efficacy target (0 = none)
    RECHECK_SCHED = 7, # days between scheduled evaluations of PLT
    INIT_REG = (AMT = 4.0, TIME = 0, II = 24, ADDL = 6), # ADDL = 6; weekly observations
);

patient_df = DataFrame(
    id = 1,
    tdd = 4,
    freqn = 24,
    scenario = SCENARIO,
    models = (; combined_pkpd)
);


function reset_patient()
    return create_patient_dict(patient_df[1, :])
end

function reset_regimen()
    return DosageRegimen(
        4000; #mg to μg
        evid = 1,   
        time = 0,
        cmt = 1,
        ii = 24,
        addl = 6
    )
end;

##################################################################
# create_patient_dict
##################################################################
create_patient_dict(patient_df[1, :])


##################################################################
# create_covariate_dict
##################################################################
create_covariate_dict(patient_df[1, :])


##################################################################
# update_regimen
##################################################################
# reset regimen
reg = reset_regimen()

# would normally take a trial_event as second positional argument but just need new_dose element
# update regimen to include day 7-14 dosing
# exect a DosageRegimen with 2 rows (t=0,168; amt =4000; each with ii = 24 and addl = 6)
update_regimen(reg, (; new_dose = 4.0), 7)


##################################################################
# expand_covariates
##################################################################
# reset regimen
reg = reset_regimen()

# update regimen to include day 7-14 dosing
updated_reg = update_regimen(reg, (; new_dose = 4.0), 7)

# test patient
testpatient = reset_patient()

# output should be a namedtuple of covariates with each value being
# a vector of length(regimen.data); one element for each dosing event to cover time-varying covariates
# only used as input in Subject constructor in sim_profile; not updated in patient dict
# otherwise would cause error in length of vector when using repeat function (exponential change in length of vector)
updated_cov_dict = expand_covariates(testpatient, updated_reg)

# confirm that "covariates" value is unchanged for pt (as expected)
testpatient["covariates"]


##################################################################
# sim_profile & get_current_pd
##################################################################
#* This block is working, but slows down the debugger; uncomment to run if change sim_profile
#=
reg = reset_regimen();
testpt = reset_patient();
# modified sim_profile so that number of days to sim is determined by pt["trial_day"]
# this means that when testing, need to update the element in pt dict manually
testpt["trial_day"] = 7;

# expect simulated observations for first 7 days of study
testsim = sim_profile(testpt, reg)

# get_current_pd takes SimulatedObservations as its input
# expect a named tuple with elements for sdma and plt
pd = get_current_pd(testsim);
=#
##################################################################
# modify_dose
##################################################################

# expect 2 b/c 2 is lowest value and logic says if attempting to go below lowest val to return that val
modify_dose(2, -1)

# expect 4, titrate by 1 level
modify_dose(2, 1)

# expect 10, can't exceed highest dose
modify_dose(10, 1)

# expect 4, taper by 1 level
modify_dose(6, -1)

# expect 35, if dose not in available doses vector, will return input
modify_dose(35, 1)

##################################################################
# therapy modifications
##################################################################

testpt = reset_patient();
testpt["current_pd"] = (sdma = 75.0, plt = 300.0);

# (sdma = 0.0, plt = 0.0, cur_dose = 4.0, new_dose = 4.0, recheck = 7, statdc = false, interrupt = false)
initiate_therapy(testpt)

# (sdma = 75.0, plt = 300.0, cur_dose = 4.0, new_dose = 4.0, recheck = 7, statdc = false, interrupt = false)
continue_therapy(testpt)

# (sdma = 75.0, plt = 300.0, cur_dose = 4.0, new_dose = 0.0, recheck = 7, statdc = false, interrupt = true)
interrupt_therapy(testpt)

# (sdma = 75.0, plt = 300.0, cur_dose = 0.0, new_dose = 2.0, recheck = 7, statdc = false, interrupt = false)
# cur_dose ≠ 0.0 b/c testpt["cur_dose"] still = 4.0, function working correctly
restart_therapy(testpt, -1)

# (sdma = 75.0, plt = 300.0, cur_dose = 4.0, new_dose = 6.0, recheck = 7, statdc = false, interrupt = false)
# note that modify uses the current dose as the input for modify_dose while restart_therapy use the last element
# of lnzdose
modify_therapy(testpt, 1)

# (sdma = 75.0, plt = 300.0, cur_dose = 4.0, new_dose = 0.0, recheck = 0, statdc = true, interrupt = false)
discontinue_therapy(testpt)

##################################################################
# evaluate_efficacy
##################################################################

# NOT AT GOAL, BUT TAPERED SO CONTINUE AT CURRENT DOSE
# new patient
testpt = reset_patient()
# set baseline
testpt["sdma0"] = 100.0
# set pd responses
testpt["current_pd"] = (sdma = 40.0, plt = 300.0)
# no taper during cycle
testpt["dose_tapered_in_cycle"] = true
# cycle 1 so can't be at goal before
testpt["at_goal_prev_cycle"] = false

testpt["current_dose"]
# (sdma = 75.0, plt = 300.0, cur_dose = 4.0, new_dose = 4.0, recheck = 7, statdc = false, interrupt = false)
evaluate_efficacy(testpt)

# AT GOAL, CONTINUE AT CURRENT DOSE
# new patient
testpt = reset_patient()
# set baseline
testpt["sdma0"] = 100.0
# set pd responses
testpt["current_pd"] = (sdma = 20.0, plt = 300.0)
# no taper during cycle
testpt["dose_tapered_in_cycle"] = false
# cycle 1 so can't be at goal before
testpt["at_goal_prev_cycle"] = false

testpt["current_dose"]
# (sdma = 75.0, plt = 300.0, cur_dose = 4.0, new_dose = 4.0, recheck = 7, statdc = false, interrupt = false)
evaluate_efficacy(testpt)


# NOT AT GOAL, CYCLE 1 (no previous) INCREASE DOSE BY 1 LEVEL
# new patient
testpt = reset_patient()
# set baseline
testpt["sdma0"] = 100.0
# set pd responses
testpt["current_pd"] = (sdma = 40.0, plt = 300.0)
# no taper during cycle
testpt["dose_tapered_in_cycle"] = false
# cycle 1 so can't be at goal before
testpt["at_goal_prev_cycle"] = false

testpt["current_dose"]
# (sdma = 75.0, plt = 300.0, cur_dose = 4.0, new_dose = 6.0, recheck = 7, statdc = false, interrupt = false)
evaluate_efficacy(testpt)


# NOT AT GOAL, CYCLE 2 (at goal previously) CONTINUE AT CURRENT DOSE
TEMPSCEN = (; SCENARIO..., EFF_TARGET_OFFSET = 30)

testpt = create_patient_dict(
    DataFrame(
        id = 1,
        tdd = 4,
        freqn = 24,
        scenario = TEMPSCEN,
        models = (; combined_pkpd)
    )[1, :]
);

# set cycle
testpt["cycle"] = 2
# set baseline
testpt["sdma0"] = 100.0
# set pd responses
testpt["current_pd"] = (sdma = 40.0, plt = 300.0)
# no taper during cycle
testpt["dose_tapered_in_cycle"] = false
# cycle 1 so can't be at goal before
testpt["at_goal_prev_cycle"] = true

testpt["current_dose"]
# (sdma = 75.0, plt = 300.0, cur_dose = 4.0, new_dose = 6.0, recheck = 7, statdc = false, interrupt = false)
# This setup is a 60% reduction and with a 30% offset for being at goal in a previous cycle that exceeds the
# 54.6% threshold needed to continue at the same dose.
evaluate_efficacy(testpt)

# update response to 40% reduction and should still see a dose increase 
# set pd responses
testpt["current_pd"] = (sdma = 60.0, plt = 300.0)
evaluate_efficacy(testpt)

##################################################################
# evaluate_patient
##################################################################

# Testing NO_DOSE_ADJ = true; expect continue_therapy
testpt = reset_patient()
testpt["current_pd"] = (sdma = 20.0, plt = 300.0);
testpt["scenario"] = (; SCENARIO..., NO_DOSE_ADJ = true);
testpt["statdc"] = false;

evaluate_patient(testpt) #* pass


# Testing cycle_day = 7, but SKIP_CDAY7 = false; expect continue_therapy
# cur_dose = 4, new_dose = 4
testpt = reset_patient()
testpt["current_pd"] = (sdma = 20.0, plt = 300.0);
testpt["statdc"] = false; # normally created in loop, needed for continue_therapy
testpt["cycle_day"] = 7

evaluate_patient(testpt) #* pass


# Testing cycle_day = 7, but SKIP_CDAY7 = false; expect continue_therapy, but from last condition
testpt = reset_patient()
testpt["current_pd"] = (sdma = 20.0, plt = 300.0);
testpt["statdc"] = false; # normally created in loop, needed for continue_therapy
testpt["cycle_day"] = 7

evaluate_patient(testpt) #* pass


# Testing cycle_day = 7, SKIP_CDAY7 = true; expect continue_therapy 1
testpt = reset_patient()
testpt["current_pd"] = (sdma = 20.0, plt = 300.0);
testpt["statdc"] = false; # normally created in loop, needed for continue_therapy
testpt["cycle_day"] = 7
testpt["scenario"] = (; SCENARIO..., SKIP_CDAY7 = true)

evaluate_patient(testpt) #* pass

# Testing cycle_day = 21; expect continue_therapy 1
testpt = reset_patient()
testpt["current_pd"] = (sdma = 20.0, plt = 300.0);
testpt["statdc"] = false; # normally created in loop, needed for continue_therapy
testpt["cycle_day"] = 21

evaluate_patient(testpt) #* pass

# Testing G3 PLT; expect interrupt_therapy
testpt = reset_patient()
testpt["current_pd"] = (sdma = 20.0, plt = 45);
testpt["cycle_day"] = 7

evaluate_patient(testpt) #* pass

# Testing G4 PLT; expect discontinue_therapy
testpt = reset_patient()
testpt["current_pd"] = (sdma = 20.0, plt = 20);
testpt["cycle_day"] = 7

evaluate_patient(testpt) #* pass

# Testing restart after interrupt; expect restart_therapy at 1 level lower
testpt = reset_patient()
testpt["current_pd"] = (sdma = 20.0, plt = 55);
testpt["cycle_day"] = 7
testpt["lnzdose"] = [4.0]
testpt["interrupt"] = true

evaluate_patient(testpt) #* pass

# Testing G2 taper, dose_tapered_in_cycle = false; expect modify_therapy with taper by 1 level
testpt = reset_patient()
testpt["current_pd"] = (sdma = 20.0, plt = 55);
testpt["cycle_day"] = 7
testpt["scenario"] = (; SCENARIO..., ADJUST_G2 = true)


evaluate_patient(testpt) #* pass

# Testing G2 taper, dose_tapered_in_cycle = false; expect continue_therapy 2 b/c already tapered during cycle
testpt = reset_patient()
testpt["current_pd"] = (sdma = 20.0, plt = 55);
testpt["cycle_day"] = 7
testpt["scenario"] = (; SCENARIO..., ADJUST_G2 = true)
testpt["dose_tapered_in_cycle"] = true
testpt["statdc"] = false

evaluate_patient(testpt) #* pass

# Testing CDAY28 evaluation; expect evaluate_therapy (no need to eval output here since tested thoroughly above)
testpt = reset_patient()
testpt["current_pd"] = (sdma = 40.0, plt = 55);
testpt["sdma0"] = 100.0
testpt["cycle_day"] = 28

evaluate_patient(testpt) #* pass

##################################################################
# sim_trial
##################################################################

# helper function to order cols and compare dfs
function compare_df(df1, df2)
    select!(df1, :cycle, :day, :cycle_day, All())
    select!(df2, :cycle, :day, :cycle_day, All())
    if df1 == df2
        return true
    else  
        isapprox.(df1,df2)
    end
end

# standardized values to check control flow
SAFE = 110; #Normal PLT
G2 = 65; # G2 safety event
G3 = 45; # G3 safety event
G4 = 15; # G4 safety event
PASS = 20; # from baseline an 80% reduction in SDMA (≥78% expected; PASS)
FAIL = 40; # from baseline a 60% reduction in SDMA (≥78% expected; FAIL)

#=
 * 1 Cycle(s)
 * No safety events
 * Day 7 evaluation
 * No G2 adjustment
 * ≥78% reduction (PASS), no adjustment at CDAY28
=#
tp = [
    (sdma=0,plt=0,cur_dose=4.0,new_dose=4.0,recheck=7,statdc=false,interrupt=false,cycle=1,day=0,cycle_day=0,current_dose_dur=0),
    (sdma=FAIL,plt=SAFE,cur_dose=4.0,new_dose=4.0,recheck=7,statdc=false,interrupt=false,cycle=1,day=7,cycle_day=7,current_dose_dur=7),
    (sdma=FAIL,plt=SAFE,cur_dose=4.0,new_dose=4.0,recheck=7,statdc=false,interrupt=false,cycle=1,day=14,cycle_day=14,current_dose_dur=14),
    (sdma=FAIL,plt=SAFE,cur_dose=4.0,new_dose=4.0,recheck=7,statdc=false,interrupt=false,cycle=1,day=21,cycle_day=21,current_dose_dur=21),
    (sdma=PASS,plt=SAFE,cur_dose=4.0,new_dose=4.0,recheck=7,statdc=false,interrupt=false,cycle=1,day=28,cycle_day=28,current_dose_dur=28),
]

testpt = reset_patient()
testpt["sdma0"] = 100.0;
testpt["plt0"] = 300.0;
testpt["profile"] = tp

# will modify test patient in place
sim_trial_validation(testpt, 1)

# should evaluate true when comparing the test profile with trial_events
compare_df(DataFrame(tp), DataFrame(testpt["trial_events"]))


#=
 * 2 Cycle(s)
 * No safety events
 * CDay 7 evaluation
 * No G2 adjustment
 * ≥78% reduction (PASS), no adjustment at C1 CDAY28
 * ≥78% reduction (PASS), no adjustment at C2 CDAY28
=# 
tp = [
    (sdma=0,plt=0,cur_dose=4.0,new_dose=4.0,recheck=7,statdc=false,interrupt=false,cycle=1,day=0,cycle_day=0,current_dose_dur=0),
    (sdma=FAIL,plt=SAFE,cur_dose=4.0,new_dose=4.0,recheck=7,statdc=false,interrupt=false,cycle=1,day=7,cycle_day=7,current_dose_dur=7),
    (sdma=FAIL,plt=SAFE,cur_dose=4.0,new_dose=4.0,recheck=7,statdc=false,interrupt=false,cycle=1,day=14,cycle_day=14,current_dose_dur=14),
    (sdma=FAIL,plt=SAFE,cur_dose=4.0,new_dose=4.0,recheck=7,statdc=false,interrupt=false,cycle=1,day=21,cycle_day=21,current_dose_dur=21),
    (sdma=PASS,plt=SAFE,cur_dose=4.0,new_dose=4.0,recheck=7,statdc=false,interrupt=false,cycle=1,day=28,cycle_day=28,current_dose_dur=28),
    (sdma=PASS,plt=SAFE,cur_dose=4.0,new_dose=4.0,recheck=7,statdc=false,interrupt=false,cycle=2,day=35,cycle_day=7,current_dose_dur=35),
    (sdma=PASS,plt=SAFE,cur_dose=4.0,new_dose=4.0,recheck=7,statdc=false,interrupt=false,cycle=2,day=42,cycle_day=14,current_dose_dur=42),
    (sdma=PASS,plt=SAFE,cur_dose=4.0,new_dose=4.0,recheck=7,statdc=false,interrupt=false,cycle=2,day=49,cycle_day=21,current_dose_dur=49),
    (sdma=PASS,plt=SAFE,cur_dose=4.0,new_dose=4.0,recheck=7,statdc=false,interrupt=false,cycle=2,day=56,cycle_day=28,current_dose_dur=56),
]

testpt = reset_patient()
testpt["sdma0"] = 100.0;
testpt["plt0"] = 300.0;
testpt["profile"] = tp

# will modify test patient in place
sim_trial_validation(testpt, 2)

# should evaluate true when comparing the test profile with trial_events
compare_df(DataFrame(tp), DataFrame(testpt["trial_events"]))


#=
 * 2 Cycle(s)
 * G3 safety at TD14, rebound at TD21
 * CDay 7 evaluation
 * No G2 adjustment
 * <78% reduction (FAIL), but NO adjustment at C1 CDAY28 b/c of previous taper
 * <78% reduction (FAIL), increase by 1 dose level C2 CDAY28
=# 
tp = [
    (sdma=0,plt=0,cur_dose=4.0,new_dose=4.0,recheck=7,statdc=false,interrupt=false,cycle=1,day=0,cycle_day=0,current_dose_dur=0),
    (sdma=FAIL,plt=SAFE,cur_dose=4.0,new_dose=4.0,recheck=7,statdc=false,interrupt=false,cycle=1,day=7,cycle_day=7,current_dose_dur=7),
    #* safety event
    (sdma=FAIL,plt=G3,cur_dose=4.0,new_dose=0.0,recheck=7,statdc=false,interrupt=true,cycle=1,day=14,cycle_day=14,current_dose_dur=14),
    (sdma=FAIL,plt=SAFE,cur_dose=0.0,new_dose=2.0,recheck=7,statdc=false,interrupt=false,cycle=1,day=21,cycle_day=14,current_dose_dur=7),
    (sdma=FAIL,plt=SAFE,cur_dose=2.0,new_dose=2.0,recheck=7,statdc=false,interrupt=false,cycle=1,day=28,cycle_day=21,current_dose_dur=7),
    #* fail, but no titration b/c tapered during cycle
    (sdma=FAIL,plt=SAFE,cur_dose=2.0,new_dose=2.0,recheck=7,statdc=false,interrupt=false,cycle=1,day=35,cycle_day=28,current_dose_dur=14),
    (sdma=PASS,plt=SAFE,cur_dose=2.0,new_dose=2.0,recheck=7,statdc=false,interrupt=false,cycle=2,day=42,cycle_day=7,current_dose_dur=21),
    (sdma=PASS,plt=SAFE,cur_dose=2.0,new_dose=2.0,recheck=7,statdc=false,interrupt=false,cycle=2,day=49,cycle_day=14,current_dose_dur=28),
    (sdma=PASS,plt=SAFE,cur_dose=2.0,new_dose=2.0,recheck=7,statdc=false,interrupt=false,cycle=2,day=56,cycle_day=21,current_dose_dur=35),
    #* fail with titration because in subsequent cycle
    (sdma=FAIL,plt=SAFE,cur_dose=2.0,new_dose=4.0,recheck=7,statdc=false,interrupt=false,cycle=2,day=63,cycle_day=28,current_dose_dur=42),
]

testpt = reset_patient()
testpt["sdma0"] = 100.0;
testpt["plt0"] = 300.0;
testpt["profile"] = tp

# will modify test patient in place
sim_trial_validation(testpt, 2)

# should evaluate true when comparing the test profile with trial_events
compare_df(DataFrame(tp), DataFrame(testpt["trial_events"]))


#=
 * 2 Cycle(s)
 * No safety events
 * CDay 7 evaluation
 * G2 adjustment 
 * <78% reduction (FAIL), but NO adjustment at C1 CDAY28 b/c of G2 adjustment
 * <78% reduction (FAIL), increase by 1 dose level C2 CDAY28
=# 
tp = [
    (sdma=0,plt=0,cur_dose=4.0,new_dose=4.0,recheck=7,statdc=false,interrupt=false,cycle=1,day=0,cycle_day=0,current_dose_dur=0),
    #* Immediate taper b/c of G2 rule
    (sdma=FAIL,plt=G2,cur_dose=4.0,new_dose=2.0,recheck=7,statdc=false,interrupt=false,cycle=1,day=7,cycle_day=7,current_dose_dur=7),
    (sdma=FAIL,plt=SAFE,cur_dose=2.0,new_dose=2.0,recheck=7,statdc=false,interrupt=false,cycle=1,day=14,cycle_day=14,current_dose_dur=7),
    (sdma=FAIL,plt=SAFE,cur_dose=2.0,new_dose=2.0,recheck=7,statdc=false,interrupt=false,cycle=1,day=21,cycle_day=21,current_dose_dur=14),
    #* Failing on CDAY 28, but no titration b/c of G2 adjustment
    (sdma=FAIL,plt=SAFE,cur_dose=2.0,new_dose=2.0,recheck=7,statdc=false,interrupt=false,cycle=1,day=28,cycle_day=28,current_dose_dur=21),
    (sdma=PASS,plt=SAFE,cur_dose=2.0,new_dose=2.0,recheck=7,statdc=false,interrupt=false,cycle=2,day=35,cycle_day=7,current_dose_dur=28),
    (sdma=PASS,plt=SAFE,cur_dose=2.0,new_dose=2.0,recheck=7,statdc=false,interrupt=false,cycle=2,day=42,cycle_day=14,current_dose_dur=35),
    (sdma=PASS,plt=SAFE,cur_dose=2.0,new_dose=2.0,recheck=7,statdc=false,interrupt=false,cycle=2,day=49,cycle_day=21,current_dose_dur=42),
    #* Failing, titrate 1 dose level
    (sdma=FAIL,plt=SAFE,cur_dose=2.0,new_dose=4.0,recheck=7,statdc=false,interrupt=false,cycle=2,day=56,cycle_day=28,current_dose_dur=49),
]

testpt = reset_patient()
testpt["sdma0"] = 100.0;
testpt["plt0"] = 300.0;
testpt["scenario"] = (; SCENARIO..., G2_ADJUST = true)
testpt["profile"] = tp

# will modify test patient in place
sim_trial_validation(testpt, 2)

# should evaluate true when comparing the test profile with trial_events
compare_df(DataFrame(tp), DataFrame(testpt["trial_events"]))


#=
 * 3 Cycle(s)
 * No safety events
 * No CDay 7 evaluation
 * G2 adjustment 
 * <78% reduction (FAIL), titatre 1 level
 * ≥78% reduction (PASS), unchanged
 * 60% reduction would normally fail, but passess with offset (see below), unchanged
=# 
tp = [
    (sdma=0,plt=0,cur_dose=4.0,new_dose=4.0,recheck=7,statdc=false,interrupt=false,cycle=1,day=0,cycle_day=0,current_dose_dur=0),
    #* "Safety" event but SKIP_CDAY7 active so dose will be unchanged
    (sdma=FAIL,plt=G3,cur_dose=4.0,new_dose=4.0,recheck=7,statdc=false,interrupt=false,cycle=1,day=7,cycle_day=7,current_dose_dur=7),
    (sdma=FAIL,plt=SAFE,cur_dose=4.0,new_dose=4.0,recheck=7,statdc=false,interrupt=false,cycle=1,day=14,cycle_day=14,current_dose_dur=14),
    #* "Safety" event but no evaluation on CDAY21 so dose will be unchanged
    (sdma=FAIL,plt=G3,cur_dose=4.0,new_dose=4.0,recheck=7,statdc=false,interrupt=false,cycle=1,day=21,cycle_day=21,current_dose_dur=21),
    #* Failing, titrate 1 dose level
    (sdma=FAIL,plt=SAFE,cur_dose=4.0,new_dose=6.0,recheck=7,statdc=false,interrupt=false,cycle=1,day=28,cycle_day=28,current_dose_dur=28),
    (sdma=PASS,plt=SAFE,cur_dose=6.0,new_dose=6.0,recheck=7,statdc=false,interrupt=false,cycle=2,day=35,cycle_day=7,current_dose_dur=7),
    (sdma=PASS,plt=SAFE,cur_dose=6.0,new_dose=6.0,recheck=7,statdc=false,interrupt=false,cycle=2,day=42,cycle_day=14,current_dose_dur=14),
    (sdma=PASS,plt=SAFE,cur_dose=6.0,new_dose=6.0,recheck=7,statdc=false,interrupt=false,cycle=2,day=49,cycle_day=21,current_dose_dur=21),
    #* This should activate at_goal_prev_cycle
    (sdma=PASS,plt=SAFE,cur_dose=6.0,new_dose=6.0,recheck=7,statdc=false,interrupt=false,cycle=2,day=56,cycle_day=28,current_dose_dur=28),
    (sdma=PASS,plt=SAFE,cur_dose=6.0,new_dose=6.0,recheck=7,statdc=false,interrupt=false,cycle=3,day=63,cycle_day=7,current_dose_dur=35),
    (sdma=PASS,plt=SAFE,cur_dose=6.0,new_dose=6.0,recheck=7,statdc=false,interrupt=false,cycle=3,day=70,cycle_day=14,current_dose_dur=42),
    (sdma=PASS,plt=SAFE,cur_dose=6.0,new_dose=6.0,recheck=7,statdc=false,interrupt=false,cycle=3,day=77,cycle_day=21,current_dose_dur=49),
    #* SDMA = 40 (ie 60% red from baseline) which should trigger titration, but won't because of target offset (lowers %red needed to meet efficacy)
    #* to ensure that increases in SDMA from RUV after initial success don't lead to titration and put the patient at risk for SAE
    (sdma=FAIL,plt=SAFE,cur_dose=6.0,new_dose=6.0,recheck=7,statdc=false,interrupt=false,cycle=3,day=84,cycle_day=28,current_dose_dur=56),
]

testpt = reset_patient()
testpt["sdma0"] = 100.0;
testpt["plt0"] = 300.0;
testpt["scenario"] = (; SCENARIO..., G2_ADJUST = true, SKIP_CDAY7 = true, EFF_TARGET_OFFSET = 30)
testpt["profile"] = tp

# will modify test patient in place
sim_trial_validation(testpt, 3)

# should evaluate true when comparing the test profile with trial_events
compare_df(DataFrame(tp), DataFrame(testpt["trial_events"]))