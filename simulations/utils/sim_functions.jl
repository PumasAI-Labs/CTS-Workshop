

function sim_profile(pt, regimen)

    # set seed to simid id so that's it's unique for each subject
    seed = pt["id"]

    # set rng
    rng = StableRNG(seed)

    # create subject
    subj = Subject(
        id = pt["id"],
        events = regimen,
        covariates = expand_covariates(pt, regimen),
        covariates_time = [x.time for x in regimen.data],
        covariates_direction = :left
    )

    # set seed
    Random.seed!(rng, seed)
    
    # sim pk/pd for trial_day=1 through current trial_day
    # all obs are effectively "pre-dose" samples for q24h dosing
    sim = simobs(
        pt["models"].combined_pkpd.mdl,
        subj,
        init_params(pt["models"].combined_pkpd.mdl),
        obstimes = collect(1:1:pt["trial_day"]) .* 24,
        rng = rng
    )

    return sim

end



function create_covariate_dict(dfr)
    
    # vector of expected covariates symbols
    covariates = dfr.scenario.COVARIATES

    # can't use select b/c no method for select(dataframerow)
    # can't use Dict(pairs(eachcol(dfr))) b/c no method for dataframerow 
    # can't use Dict(pairs(dfr[cov])) b/c values won't be vectors which breaks expand_covariates

    # empty dict PH
    cov_dict = Dict()

    # add values as vectors by looping over cov
    if length(covariates) > 0
        for cov in covariates
            cov_dict[cov] = [dfr[cov]]
        end
    end

    return cov_dict

end



function expand_covariates(pt, regimen)
    
    cov_dict = deepcopy(pt["covariates"]) #! has to be a deepcopy or will cause chaos in sims
    nreps = length(regimen.data) # using this b/c of potential single evid=2 events 

    # !for-loop only works if v is a vector; can't change the type of element once the dict is created
    if length(cov_dict) > 0
        for (k,v) in cov_dict
            cov_dict[k] = repeat(v, nreps)
        end
    end

    # calculate total daily dose (tdd) based on amt and ii
    amts = [x.amt/1000 for x in regimen.data];
    freqn = [x.ii for x in regimen.data];
    tdd = amts .* (24 ./ freqn)


    # * leaving this in case need ref for adding a time-varying cov like lnzdose
    #//cov_ntp = (; cov_dict..., lnzdose = pt["lnzdose"]) 
    cov_ntp = (; cov_dict..., tdd, freqn)

    return cov_ntp
    
end


function create_patient_dict(dfr)

    pt = Dict(
        "id" => dfr.id[1],
        "status" => 1, # 1: active, 2: inactive
        "current_dose_dur" => 0,
        "trial_day" => 0,
        "cycle_day" => 0,
        "current_dose" => dfr.scenario.INIT_REG.AMT,
        "previous_dose" => dfr.scenario.INIT_REG.AMT,
        "lnzdose" => [dfr.scenario.INIT_REG.AMT,], #vector for covariate, will expand each week
        "dose_tapered_in_cycle" => false,
        "interrupt" => false, # interrupt always leads to at least 1 DT
        "pdc_cnt" => 0,
        "statdc" => false,
        "at_goal_prev_cycle" => false,
        "covariates" => create_covariate_dict(dfr),
        "models" => dfr.models,
        "scenario" => dfr.scenario,
    )

    return pt

end



function get_current_pd(s::Pumas.SimulatedObservations)
    # the last element of the s.observations.x vector will always be the current obs
    return (sdma = s.observations.sdma[end], plt = s.observations.plt[end])
end 



function evaluate_efficacy(pt)

    # ntp of current pd values
    pd = pt["current_pd"]

    # unpacking scenario variables for readability
    eff_red_from_bl = 1 - (pd.sdma/pt["sdma0"])
    EFF_TARGET = pt["scenario"].EFF_TARGET / 100
    EFF_TARGET_OFFSET = pt["scenario"].EFF_TARGET_OFFSET / 100

    # titration not allowed if dose tapered during current cycle
    if pt["dose_tapered_in_cycle"]
        return continue_therapy(pt)
    end

    # if goal reduction was achieved in previous cycle lower efficacy threshold to make
    # it more difficult to increase dose (prevents titration d/t noise and lowers risk of SAE)
    if pt["at_goal_prev_cycle"]
        EFF_TARGET = (1 - EFF_TARGET_OFFSET) * EFF_TARGET
    end

    # if reduction in SDMA from BL < target, increase dose, else continue current dose
    if eff_red_from_bl < EFF_TARGET
        return modify_therapy(pt, 1)
    else
        return continue_therapy(pt)
    end

end



function modify_dose(current_dose, step)

    # vector of available drug doses
    doses = [2.0,4.0,6.0,8.0,10.0]

    # search for index of current dose level
    srch = findall(==(current_dose), doses)
    
    # if current dose not in array, return current dose
    if length(srch) == 0
        return current_dose
    end

    # index of new dose level is old level index + step (can be + or -)
    new_level = srch[1] + step

    # if dose_level after step would be < 2 return 2
    # if dose_level after step would be > 10 return 10
    # else return new_dose by index
    new_dose = new_level < 1 ? doses[begin] :
        new_level > length(doses) ? doses[end] :
        doses[new_level]

    return new_dose

end



function initiate_therapy(pt)

    return (
        sdma = 0.0, # !FIXME: temporary value needs to be replaced with SDMA0 from model
        plt = 0.0, # !FIXME: temporary value needs to be replaced with CIRC0 from model
        cur_dose = pt["scenario"].INIT_REG.AMT,
        new_dose = pt["scenario"].INIT_REG.AMT, 
        recheck = pt["scenario"].RECHECK_SCHED,
        statdc = false,
        interrupt = false,
    )

end



function continue_therapy(pt)
    
    return (
        sdma = pt["current_pd"].sdma,
        plt = pt["current_pd"].plt, 
        cur_dose = pt["current_dose"],
        new_dose = pt["current_dose"], 
        recheck = pt["scenario"].RECHECK_SCHED,
        statdc = pt["statdc"],
        interrupt = pt["interrupt"],
    )

end



function interrupt_therapy(pt)
 
    return (
        sdma = pt["current_pd"].sdma,
        plt = pt["current_pd"].plt, 
        cur_dose = pt["current_dose"],
        new_dose = 0.0, 
        recheck = pt["scenario"].RECHECK_SCHED,
        statdc = false,
        interrupt = true,
    )

end



function restart_therapy(pt, step)

    return (
        sdma = pt["current_pd"].sdma,
        plt = pt["current_pd"].plt, 
        cur_dose = pt["current_dose"],
        new_dose = modify_dose(pt["lnzdose"][end], step), 
        recheck = pt["scenario"].RECHECK_SCHED,
        statdc = false,
        interrupt = false,
    )

end



function modify_therapy(pt, step)

    return (
        sdma = pt["current_pd"].sdma,
        plt = pt["current_pd"].plt, 
        cur_dose = pt["current_dose"],
        new_dose = modify_dose(pt["current_dose"], step), 
        recheck = pt["scenario"].RECHECK_SCHED,
        statdc = false,
        interrupt = false,
    )

end



function discontinue_therapy(pt)
    
    return (
        sdma = pt["current_pd"].sdma,
        plt = pt["current_pd"].plt, 
        cur_dose = pt["current_dose"],
        new_dose = 0.0, 
        recheck = 0,
        statdc = true,
        interrupt = true,
    )

end



function update_regimen(current_regimen, trial_event, trial_day)

    # new regimen to be given during next sim iteration
    new_regimen = trial_event.new_dose > 0 ?
        DosageRegimen(trial_event.new_dose * 1000; time = trial_day*24, cmt = 1, ii = 24, addl = 6) :
        # can't use ii and addl with evid = 2 so using reduce to get individual events for 1w of held doses
        reduce(DosageRegimen, [DosageRegimen(0, time=t, evid=2, cmt=1) for t in (trial_day*24):24:((trial_day*24)+144)])

    # combine previous regimen and new regimen for complete dosing history
    return DosageRegimen(
        current_regimen,
        new_regimen
    )

end



function evaluate_patient(pt)

    # named tuple with current day's eval metrics (sdma, plt)
    pd = pt["current_pd"]

    #= 
        * This is an escape condition; a way to bypass all of the logic that follows because
        * every if-else block below this one has the ability to modify therapy in some way.
        * NO_DOSE_ADJ gives us access to the "regular" sim that was performed in the mansucript
        * CDAY = 7 & SKIP_CDAY7 let us skip the "visit" at CDAY 7 (sometimes it's easier to code for when NOT to do something)
        * - need to specify CDAY along with the skip or anytime SKIP_CDAY7 is true, the script will simply continue without evaluating the therapy
        * Always skip the "visit" at CDAY 21
    =# 
    # If any of these are TRUE, continue current therapy without any modification or status change
    if pt["scenario"].NO_DOSE_ADJ || (pt["cycle_day"] == 7 && pt["scenario"].SKIP_CDAY7) || pt["cycle_day"] == 21
        #//@info "continue_therapy 1"
        return continue_therapy(pt)
    end

    # check safety (any PLT value <G3 threshold considered "unsafe")
    if pd.plt < pt["scenario"].PLT_G3
        if pd.plt < pt["scenario"].PLT_G4
            #//@info "discontinue_therapy"
            return discontinue_therapy(pt)
        else
            #//@info "interrupt therapy"
            return interrupt_therapy(pt)
        end
    end

    # check for interrupt and restart if PLT ≥ G3 threshold
    if pt["interrupt"]
        #//@info "restart_therapy"
        return restart_therapy(pt, -1)
    end
    #=
        * Option to immediately taper the dose of a patient with G2 CIT, but not G3 in effort to prevent AE from progressing
        * Only available at CDAY 7 or 15
        * Not allowed if they're already on the lowest dose (2mg) or if they've already been tapered at another point during the current cycle
    =#
    # check whether patient is at risk for SAE (G2 CIT)
    if pt["cycle_day"] ≠ 28 && (pd.plt < pt["scenario"].PLT_G2 && pt["scenario"].G2_ADJUST) && (!pt["dose_tapered_in_cycle"] && pt["current_dose"] > 2)
        #//@info "modify_therapy"
        return modify_therapy(pt, -1)
    end

    #=
        * Titration to higher dose only available on CDAY28
        * CDAY should not be able to exceed 28, but as a failsafe, it will evaluate as continue_therapy and cycle will increase at the end of the loop resetting CDAY

    =#
    if pt["cycle_day"] == 28
        #//@info "evaluate_therapy"
        return evaluate_efficacy(pt)
    else
        #//@info "continue_therapy 2"
        return continue_therapy(pt)
    end

end


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


##################################################################
# FOR VALIDATION USE ONLY!
##################################################################
function sim_trial_validation(pt, ncycles)
    #* INPUTS MODIFIED FOR VALIDATION PURPOSES
    #* DO NOT USE FOR REGULAR SIMULATION
    # set cycle counter
    cycle = 1

    #! Modified for validation
    # create patient dictionary
    #//pt = create_patient_dict(dfr)

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
        #! Disabled this input for validation, will pass pt["profile"] as an external vector
        #//pt["profile"] = sim_profile(pt, regimen)

        #! Disabled for validation
        #=
        # add SDMA0 and PLT0 to patient after first sim_profile run
        if pt["trial_day"] == 7
            pt["sdma0"] = pt["profile"].icoefs.sdma0[end]
            pt["plt0"] = pt["profile"].icoefs.circ0[end]
        end
        =#

        # update duration at current dose
        # TODO: explain why this is done in this order (b/c the dose isn't 'given' until sim_profile is called)
        pt["current_dose_dur"] = pt["current_dose"] == pt["previous_dose"] ? 
            pt["current_dose_dur"] += pt["scenario"].RECHECK_SCHED : # ? may be better to fix this to be +x; where x is a standard time interval (ie, 7d)
            pt["scenario"].RECHECK_SCHED # ? may be better to fix this along with the above

        #! Modified for validation
        # named tuple of current pd values (sdma, plt)
        #//pt["current_pd"] = get_current_pd(pt["profile"])
        pt["current_pd"] = filter(ntp -> ntp.day == pt["trial_day"], pt["profile"])[1]

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