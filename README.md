# Advanced Clinical Trial Simulation Workshop

# Introduction
* {Note the wording of this section will be expanded}
* Intended for advanced users
* If not an advanced user, concepts will still be valuable and this example can be used as a mechanism for learning more advanced topics


# Prerequisites
* Familiar with modeling and simulation workflows in Pumas.
* Understanding of basic programming concepts (e.g., control flow, boolean operations, functions).
* Familiar with data types used in Julia and how to access information stored within them.

# Case Study

## Reference
* PK/PD model-informed dose selection for oncology phase I expansion: Case study based on PF-06939999, a PRMT5 inhibitor. doi: 10.1002/psp4.12882

## Overview
* Used PK/PD modeling to select a recommended dose (PF06) for expansion based on first in patient data collected from a Phase 1 dose escalation trial that included 28 patients with solid tumors.
    + 0.5-8mg PO q12h
    + 0.5-6mg PO q24h
* PF06 is a small molecule inhibitor of protein arginine methyltransferase 5 (PRMT5)
* Two PD biomarkers in study ("efficacy" and "safety")
    + Symmetrical dimethyl-arginine (SDMA): catabolic product of PRMT5 activity. Reduction in SDMA has been correlated with tumor response. Specifically a 78% reduction in plasma SDMA was shown to correspond with nearly complete inhibition of tumor SDMA.
    + Platelet count: thrombocytopenia is the most common adverse event for drugs in the same class.
* Grading (severity) of adverse events (thrombocytopenia)
    + G1 = <100 10⁹cells/L
    + G2 = <75
    + G3 = <50 (bad)
    + G4 = <25 (real bad)
    * 30-35% G3 or above acceptable

## Demographics
* Age (y): 63 (33, 85) median (min,max)
* TBW (kg): 89 (55, 137)
* Sex (M:F), 15:13
* Race (1:5), 3:25; 1=AA, 5=white
* Liver function (1:2), 24:4; 1=normal, 2=mild impairment
* ECOG PS (0:1), 6:22;

## Sample Collection
### PK Sampling
* Cycle 1
    + Day 1: 0, 0.5, 1, 2, 4, 6, and 12 (bid) or 24 (qD)
    + Day 8: Pre-dose
    + Day 15: 0, 0.5, 1, 2, 4, 6 and 12 (bid) or 24 (qD)
    + Day 22: Pre-dose
* All remaining cycles
    + Day 1: Pre-dose

### SDMA
* Cycle 1
    + Day 1: 0, 2, 6, and 12 (bid) or 24 (qD)
    + Day 8: Pre-dose
    + Day 15: 0, 2, 6, and 12 (bid) or 24 (qD)
    + Day 22: Pre-dose
* Remaining Cycles
    + Day 1: Pre-dose

### Hematology
* Cycle 1
    + Day 1, 8, 15, 22: Pre-dose
* Remaining Cycles
    + Day 1, 15: Pre-dose

## Results
* Chose to simulate using once-daily dosing (0.5-12mg)
* Number of cycles simulated unclear
* On Day 15 (assume cycle 1) 
    + 4mg PO q24h probability of target attainment was 64% while probability of G3 AE was 17%
    + 6mg PO q24h probability of target attainment was 76% while probability of G3 AE was 30%
    + 8mg PO q24h probability of target attainment was 81% while probability of G3 AE was 43%
* Chose to move forward with 6mg PO q24h

# CTS Exercise

## Rationale
For each simulation in the manuscript, all subjects were given the same dose of PF06 without an opportunity to modify their dose based upon either PD response. It's possible that allowing for dose modification could increase the probability of target attainment while further minimizing the risk of serious adverse events. Realistically, it's a little early in the drug's development cycle to consider these questions, but they provide an excellent justification for performing a more advanced simulation.

## Key Questions
1. Can the results of the original simulation (specifically 4-8mg PO q24h) be reproduced in Pumas?
2. Would starting all patients at the lower end of the simulated range (4mg) and allowing for dose modification based upon PD response further improve both safety and efficacy metrics?
3. The first follow-up for the original simulations was at cycle day 15. Would an earlier follow-up at cycle day 7 with the potential to taper the starting dose prevent subjects from experiencing more severe AEs?


## Guidelines

### DRY principle
* If typing it more than twice, turn it into a function

```
a = (b + c) * 4
d = a/2

e = (f + g) * 4
h = e/2

function f(var1, var2)
    x = (var1 + var2) * 4/2
    return x
end
```

### Modularization
* The trial workflow should be controlled by a single "main" function that calls additional "helper" functions as needed.
* Each trial action (e.g., dose titration) should be implemented as a separate function
    + Create a mechanism to test/validate each function

```
function mytrial()

    f1()

    f2()

    f3()

    return result

end
```

### Data Structures
* Dataframes are computationally expensive; try to avoid during simulation.
    + Try to stick with built-in types (named tuples, dictionaries, Pumas constructors); can be challenging!
* Dataframes store more than just tabular data which makes the ideal for storing the result of a set of simulations

### User-Defined Types
* Scenario: a named tuple of keyword options that will be used to change how simulations are conducted

```
(
    STARTINGDOSE = 4,
    DAYSOFTHERAPY = 15
)
```

* Trial Events: a `NamedTuple` that stores key information for each simulated "visit"

```
(
    day = 7,
    pkval = 92.3,
    pdval = 50.1,   
)
```

* Patient: a dictionary used to store multi-type data about the "experimental unit" 
    + A dataframe might work but they're expensive
    + A NamedTuple would be difficult to use because, once created, the stored values are difficult to edit

```
patient = Dict(
    "id" => 1,
    "trialdetail1" => DataFrame,
    "trialdetail2" => Dict("key1" => 1, "key2" => [1,2,3])?
)
```

## Execution

* First, get things working for a single patient then worry about scaling up!
* Start from a dataframe of patients where each row represents a unique patient.
* Map over each row in the dataframe, simulating a full set of observations for each patient and storing them in a new df column.

```
df[!, :sim] = map(eachrow(df)) do r
    mytrial(r, 3) # example of 3 cycles
end
```

* Multiple Scenarios (runs) will need to be explored and our goal is to use distributed processing to accomplish that quickly
* The results of each distributed run will be combined in a single dataframe which is the input for post processingdataframe

```
 Row │ run    pop    scenario  
─────┼────────────────────────
   1 │     1      1  BASELINE
   2 │     2      1  SCENARIO1
```



## Execution

```julia

function sim_trial(dfr, ncycles)

    # set cycle counter
    cycle = 1

    # create patient dictionary
    pt = create_patient_dict(dfr)

    # set starting regimen
    regimen = DosageRegimen(
        pt["scenario"].INIT_REG.AMT * 1000; #mg to μg
        evid = 1,   
        time = pt["scenario"].INIT_REG.TIME,
        cmt = 1,
        ii = 24,
        addl = pt["scenario"].INIT_REG.ADDL
    )

    # create first trial event; i.e. begin treatment
    trial_event = initiate_therapy(pt)

    # add trial day and duration of current dose to trial_event and store in vector for later
    # ! remember dict elements are passed by ref and pt["cycle_day"] may cause issues here
    trial_events = [(trial_event..., cycle = cycle, day = pt["trial_day"], cycle_day = pt["cycle_day"], current_dose_dur = 0)]

    # loop through and evaluated patients q4w beginning at 4w through ndays
    while cycle ≤ ncycles
        
        # check patient status to confirm eligible to continue
        if pt["status"] != 1
            break
        end

        # set first non-zero dose given at start of current cycle which will be reference for flagging taper
        pt["dose_at_cycle_start"] = pt["cycle_day"] == 0 ? pt["lnzdose"][end] : pt["dose_at_cycle_start"]

        #trial_day += 1 # * this version is for incrementing by 1 trial day
        pt["trial_day"] = pt["trial_day"] + pt["scenario"].RECHECK_SCHED

        # * here, cycle day is defined as a day where the patient received drug (i.e., current_dose > 0)
        # update cycle day
        pt["cycle_day"] = pt["current_dose"] > 0 ? pt["cycle_day"] + pt["scenario"].RECHECK_SCHED : pt["cycle_day"]

        # simulate PK/PD through current day
        # * this is the 'dose administration' step and conceptually, is what 'moves' the trial day forward
        pt["profile"] = sim_profile(pt, regimen)

        # add SDMA0 and PLT0 to patient after first sim_profile run
        if pt["trial_day"] == 7
            pt["sdma0"] = pt["profile"].icoefs.sdma0[end]
            pt["plt0"] = pt["profile"].icoefs.circ0[end]
        end

        # update duration at current dose
        # TODO: explain why this is done in this order (b/c the dose isn't 'given' until sim_profile is called)
        pt["current_dose_dur"] = pt["current_dose"] == pt["previous_dose"] ? 
            pt["current_dose_dur"] += pt["scenario"].RECHECK_SCHED : # ? may be better to fix this to be +x; where x is a standard time interval (ie, 7d)
            pt["scenario"].RECHECK_SCHED # ? may be better to fix this along with the above


        # named tuple of current pd values (sdma, plt)
        pt["current_pd"] = get_current_pd(pt["profile"])

        # evaluate current dose through current day and determine next dose
        trial_event = evaluate_patient(pt)

        # add trial_event to trial_events
        push!(trial_events, (trial_event..., cycle = cycle, day = pt["trial_day"], cycle_day = pt["cycle_day"], current_dose_dur = pt["current_dose_dur"]))

        # update interrupt status post eval
        pt["interrupt"] = trial_event.interrupt

        # update dose information
        pt["current_dose"] = trial_event.new_dose # new becomes current
        pt["previous_dose"] = trial_event.cur_dose # current becomes previous

        # flag indicating whether dose was tapered at any point during current cycle
        pt["dose_tapered_in_cycle"] = !iszero(trial_event.new_dose) && trial_event.new_dose < pt["dose_at_cycle_start"]

        # check if patient flagged for permanent dc d/t G4 AE
        if trial_event.statdc == true
            pt["status"] = 2
            continue
        end

        # check if therapy was interrupted
        # increase counter if interrupted at 2mg and flag for d/c if count > 1
        if trial_event.interrupt == true
            # if interrupted while on 2mg increase d/c count by 1
            if pt["previous_dose"] == 2.0
                pt["pdc_cnt"] += 1
                # if d/c count reaches 2, d/c therapy
                if pt["pdc_cnt"] == 2
                    pt["status"] = 2
                    continue
                end
            end
        end

        # update dosing regimen to include next dose
        regimen = update_regimen(regimen, trial_event, pt["trial_day"])

        # first lnzdose value is set to first dose
        # used to track non-zero doses and when restarting tx
        pt["lnzdose"] = push!(
            pt["lnzdose"],
            pt["current_dose"] > 0 ? pt["current_dose"] : pt["lnzdose"][end]
        )

        # update lnzdose and ddi_flags if trial_event.new_dose = 0
        if trial_event.new_dose == 0
            pt["lnzdose"] = append!(pt["lnzdose"], repeat([pt["lnzdose"][end]], 6))
        end

        # increase cycle and reset cycle day
        # ! using ≥28 for now as a defensive measure to make sure while-loop isn't infinite
        if pt["cycle_day"] ≥ 28
            cycle += 1
            pt["cycle_day"] = 0
            # once this evaluates to true, it doesn't repeat the evaluation again
            pt["at_goal_prev_cycle"] = !pt["at_goal_prev_cycle"] && (1-(trial_event.sdma/pt["sdma0"]) ≥ pt["scenario"].EFF_TARGET/100) ? true : false
        end

    end

    # store final trial events vector
    pt["trial_events"] = trial_events
    pt["regimen"] = regimen

    # return patient object
    return pt

end

```