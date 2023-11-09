function sim_trial(dfr, ncycles)

    # set cycle counter
    cycle = 1

    #* create a dictionary of patient information that will keep track of trial variables
    #* and can be updated throughout the simulation
    
    #* create an initial dosing regimen that will be the starting point for simulation dosing
    #* need to be able to make starting dose different for each sim if needed
    
    #* "begin treatment" by creating the first trial_event which contains day 0 values for each key

    #* need to track current trial day and duration of current dose (probably add to trial_event)
    
    #* simulate weekly observations for a maximum of 3 cycles but only evaluate
    #* safety and efficacy on appropriate days
    #! have to use a while loop because sim won't always be 84 cycle days (interrupts freeze cycle day count)
    while cycle ≤ ncycles
        
        #* need a variable to track the patient's status starting with just whether
        #* they should continue for the current round of sims or should the sim stop

        #* need to keep track of dose subject is receiving at the start of each cycle because
        #* it can affect whether dose can be modified later or whether patient should d/c therapy

        #* need a variable to track the day of the trial and to increment it based on the
        #* chosen time between scheduled visits

        #* need a variable to track cycle day that's independent of trial day
        #* cycle day only increases if the patient is active receiving drug and should otherwise remain the same

        # simulate PK/PD through current day
        #* need to simulate the profile through the current day
        #! conceptually, this is what 'moves' the trial day forward from the previous day

        # add SDMA0 and PLT0 to patient after first sim_profile run
        #* Baseline SDMA and PLT are model params and will need to be added to the patient dictionary
        #* but they are only available after the sim has run at least once

        #* add a variable to keep track of the length of time (days) the patient has been at their
        #* current dose level, if dose changes, the count should reset to 0 days
        #* Done in this order b/c the dose isn't 'given' until sim_profile is called

        #* add a varaible for tracking the current PD metrics; simobs will contain a lot of information
        #* that isn't needed at "follow-up," only the most recent values for PK/PD are needed

        #* need a function that performs a "follow-up" visit and returns the result of the visit as a
        #* trial_event, but this should only happen on pre-specified days which should also be determined
        #* in this function

        #* add the current trial_event to the container that stores all trial events so it can be
        #* exported later. May also need to add other "loop" related information to make analysis easier

        #* check if "follow-up" determination was that patient needs to hold or d/c drug
        #* if so, update interrupt flag using current trial_event

        #* update dosing informaiton
        #* current dose should become previous dose
        #* new dose should become current dose

        #* keep up with whether dose was decreased at any point during the simulation
        #* to do that, check whether new dose is lower than the dose at the start of the current cycle
        #* during every loop iteration
        
        #* if a SAE occurs, flag the patient and stop therapy immediately, move to the next patient

        #* create a counter variable for times the patient's therapy gets interrupted
        #* if counter ≥2 interruptions at the lowest dose will remove the patient from the trial

        #* update the patient's regimen with the new dose

        #* dose can be set to zero if interrupted and when it restarts it will be at one
        #* dose level below the previous dose (eg 6 -> 4mg) but can't just use previous dose
        #* variable because the value will be zero at restart, need to keep track of last
        #* non-zero dose given throughout the sim

        #* increment cycle day and if it's cycle_day 28, increase cycle counter
        #* also need to know if patient achieved therapeutic target during the current cycle
        #* and that should only be assessed on day 28
        #! using ≥28 for now as a defensive measure to make sure while-loop isn't infinite
        
    end

    #* once the loop is finished add all of the profile and trial_event data to the patient object

    #* return patient object
    return pt

end
