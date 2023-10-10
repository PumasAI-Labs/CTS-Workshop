##################################################################
# Helper Functions and Data
##################################################################

# models
integrated = include("integrated.jl");

SCENARIO1 = (
    NO_DOSE_ADJ = false, # disable dose adjustment logic and simulate all cycles at 1 dose
    SKIP_CDAY7 = false,
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
    scenario = SCENARIO1,
    models = (; integrated)
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
updated_reg = update_regimen(reg, (; new_dose, 4.0), 7)

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
SCENARIO2 = (
    NO_DOSE_ADJ = false, # disable dose adjustment logic and simulate all cycles at 1 dose
    SKIP_CDAY7 = false,
    PLT_G4 = 25,
    PLT_G3 = 50,
    PLT_G2 = 75,
    RESP_VARS = (SDMA = :sdma, PLT = :plt), # :sdma
    EFF_TARGET = 78, # 78% reduction in SDMA from baseline
    EFF_TARGET_OFFSET = 30, # % reduction in efficacy target (0 = none)
    RECHECK_SCHED = 7, # days between scheduled evaluations of PLT
    INIT_REG = (AMT = 4.0, TIME = 0, II = 24, ADDL = 6), # ADDL = 6; weekly observations
);

testpt = create_patient_dict(
    DataFrame(
        id = 1,
        tdd = 4,
        freqn = 24,
        scenario = SCENARIO2,
        models = (; integrated)
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