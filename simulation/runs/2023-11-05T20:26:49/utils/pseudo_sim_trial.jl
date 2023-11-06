function sim_trial(dfr, ncycles)

    # set cycle counter
    cycle = 1

    # create patient dictionary
    #* create a dictionary of patient information that will keep track of trial variables
    #* and can be updated throughout the simulation
    #//pt = create_patient_dict(dfr)

    # set starting regimen
    #* create an initial dosing regimen that will be the start point for simulation dosing
    #* should be able to make starting dose different for each sim if needed
    #=
    regimen = DosageRegimen(
        pt["scenario"].INIT_REG.AMT * 1000; #mg to μg
        evid = 1,   
        time = pt["scenario"].INIT_REG.TIME,
        cmt = 1,
        ii = 24,
        addl = pt["scenario"].INIT_REG.ADDL
    )=#

    #* create first trial event; i.e. begin treatment
    #trial_event = initiate_therapy(pt)

    #* add trial day and duration of current dose to trial_event and store in vector for later
    # ! remember dict elements are passed by ref and pt["cycle_day"] may cause issues here
    #//trial_events = [(trial_event..., cycle = cycle, day = pt["trial_day"], cycle_day = pt["cycle_day"], current_dose_dur = 0)]

    #* simulate weekly observations for a maximum of 3 cycles but only evaluate
    #* safety and efficacy on appropriate days
    while cycle ≤ ncycles
        
        # check patient status to confirm eligible to continue
        #* need a variable to track the patient's status starting with just whether
        #* the should continue for this current round of sims or should the sim stop

        # set first non-zero dose given at start of current cycle which will be reference for flagging taper
        #* need to keep track of dose at the start of each cycle because it can affect whether
        #* dose is titrated/tapered later or whether patient should d/c therapy if it's low enough
        #//pt["dose_at_cycle_start"] = pt["cycle_day"] == 0 ? pt["lnzdose"][end] : pt["dose_at_cycle_start"]

        #trial_day += 1 # * this version is for incrementing by 1 trial day
        #* need a variable to track the day of the trial and to increment it based on the
        #* chosen time between scheduled visits
        #//pt["trial_day"] = pt["trial_day"] + pt["scenario"].RECHECK_SCHED

        # * here, cycle day is defined as a day where the patient received drug (i.e., current_dose > 0)
        # update cycle day
        #* need a variable to track cycle day which can be independent of trial day
        #* cycle day only increases if the patient is active receiving drug and should otherwise
        #* remain the same
        #//pt["cycle_day"] = pt["current_dose"] > 0 ? pt["cycle_day"] + pt["scenario"].RECHECK_SCHED : pt["cycle_day"]

        # simulate PK/PD through current day
        # * this is the 'dose administration' step and conceptually, is what 'moves' the trial day forward
        #* simulate and store observation through the current trial day based upon current regimen
        #* which is either the starting regimen (first loop) or is based on the trial_events up to this point
        #//pt["profile"] = sim_profile(pt, regimen)

        # add SDMA0 and PLT0 to patient after first sim_profile run
        #* need to add baseline SDMA and PLT to patient dictionary but they 
        #* are model parameters so they can only be recorded after the first simulation
        #=if pt["trial_day"] == 7
            pt["sdma0"] = pt["profile"].icoefs.sdma0[end]
            pt["plt0"] = pt["profile"].icoefs.circ0[end]
        end=#

        # update duration at current dose
        #* add a variable to keep track of the length of time (days) the patient has been at their
        #* current dose level, if dose changes, the count should reset to 0 days
        # TODO: explain why this is done in this order (b/c the dose isn't 'given' until sim_profile is called)
        #=pt["current_dose_dur"] = pt["current_dose"] == pt["previous_dose"] ? 
            pt["current_dose_dur"] += pt["scenario"].RECHECK_SCHED : # ? may be better to fix this to be +x; where x is a standard time interval (ie, 7d)
            pt["scenario"].RECHECK_SCHED # ? may be better to fix this along with the above
        =#

        # named tuple of current pd values (sdma, plt)
        #* simobs will contain a lot of information that isn't needed at "follow-up," only
        #* the most recent values for PK/PD are needed and they can be pulled out into a separate variable
        #//pt["current_pd"] = get_current_pd(pt["profile"])

        # evaluate current dose through current day and determine next dose
        #* need a function that performs a "follow-up" visit and returns the result of the visit as a
        #* trial_event, but this should only happen on pre-specified days which should also be determined
        #* in this function
        #//trial_event = evaluate_patient(pt)

        # add trial_event to trial_events
        #* add the current trial_event to the container that stores all trial events so it can be
        #* exported later. May also need to add other "loop" related information to make analysis easier
        #* once recorded, should update key trial variables like whether or not therapy was interrupted
        #//push!(trial_events, (trial_event..., cycle = cycle, day = pt["trial_day"], cycle_day = pt["cycle_day"], current_dose_dur = pt["current_dose_dur"]))

        # update interrupt status post eval
        #* update the interrupt variable with latest value from current trial_event
        #//pt["interrupt"] = trial_event.interrupt

        # update dose information
        #* current dose should become previous dose
        #* new dose should become current dose
        #//pt["current_dose"] = trial_event.new_dose # new becomes current
        #//pt["previous_dose"] = trial_event.cur_dose # current becomes previous

        # flag indicating whether dose was tapered at any point during current cycle
        #* need to track whether dose was decreased at any point during the simulation so at each
        #* event check whether the new dose is lower than the dose at the start of the current cycle
        #//pt["dose_tapered_in_cycle"] = !iszero(trial_event.new_dose) && trial_event.new_dose < pt["dose_at_cycle_start"]

        # check if patient flagged for permanent dc d/t G4 AE
        #* if a SAE occurs, flag the patient and stop therapy immediately, move to the next patient

        #=if trial_event.statdc == true
            pt["status"] = 2
            continue
        end=#

        # check if therapy was interrupted
        # increase counter if interrupted at 2mg and flag for d/c if count > 1
        #* if the patient's therapy gets interrupte will need to increase a counter variable
        #* because 2 interruptions at the lowest dose will remove the patient from the trial
        #=if trial_event.interrupt == true
            # if interrupted while on 2mg increase d/c count by 1
            if pt["previous_dose"] == 2.0
                pt["pdc_cnt"] += 1
                # if d/c count reaches 2, d/c therapy
                if pt["pdc_cnt"] == 2
                    pt["status"] = 2
                    continue
                end
            end
        end=#

        # update dosing regimen to include next dose
        #* update the patient's regimen with the new dose that will be carried forward
        #* until the next "follow-up"
        #//regimen = update_regimen(regimen, trial_event, pt["trial_day"])

        # first lnzdose value is set to first dose
        # used to track non-zero doses and when restarting tx
        #* dose can be set to zero if interrupted and when it restarts it will be at one
        #* dose level below the previous dose (eg 6 -> 4mg) but can't just use previous dose
        #* variable because the value will be zero at restart, need to keep track of last
        #* non-zero dose given throughout the sim
        #=pt["lnzdose"] = push!(
            pt["lnzdose"],
            pt["current_dose"] > 0 ? pt["current_dose"] : pt["lnzdose"][end]
        )=#

        # update lnzdose and ddi_flags if trial_event.new_dose = 0
        #* hack getting around fact can't use addl with EVID=2 and amt =0
        #=if trial_event.new_dose == 0
            pt["lnzdose"] = append!(pt["lnzdose"], repeat([pt["lnzdose"][end]], 6))
        end=#

        # increase cycle and reset cycle day
        #* increment cycle day and if it's cycle_day 28, increase cycle counter
        #* also need to know if patient achieved therapeutic target during the current cycle
        #* and that should only be assessed on day 28
        # ! using ≥28 for now as a defensive measure to make sure while-loop isn't infinite
        #=if pt["cycle_day"] ≥ 28
            cycle += 1
            pt["cycle_day"] = 0
            # once this evaluates to true, it doesn't repeat the evaluation again
            pt["at_goal_prev_cycle"] = !pt["at_goal_prev_cycle"] && (1-(trial_event.sdma/pt["sdma0"]) ≥ pt["scenario"].EFF_TARGET/100) ? true : false
        end=#

    end

    # store final trial events vector
    #* once the loop is finished add all of the profile and trial_event data to the patient
    #* object
    #//pt["trial_events"] = trial_events
    #//pt["regimen"] = regimen

    # return patient object
    return pt

end
