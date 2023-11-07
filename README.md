# Advanced Clinical Trial Simulation Workshop

# Introduction
* This workshop will show you how to implement a complex, real-world, clinical trial simulation (CTS) workflow in Pumas.
* The code that we will present is complex, and you are NOT expected to fully understand every line during the workshop.
* Our goal is to provide you a framework for learning how to use these techniques in your own work, and to leave you with a well-documented example to fall back on as you explore and learn more about CTS in Pumas.
* A basic unstanding of both Pumas and Julia will be needed to engage with the coding sections of this workshop.
    + You should have received an email directing you to the Pumas onboarding materials at labs.pumas.ai.
    + A (brief) primer on Julia basics can be found in the `resources` folder. 
* If you are wholly unfamiliar with either Pumas or Julia (or both), that's okay, the workshop will still be useful for you, but you will need to focus more on the concepts than the code until you become more familiar with the platform(s).

# Objectives
* Become familiar with the tools available for implementing advanced CTS workflows in Julia using Pumas.
* Learn how to convert CTS objectives into processes that can then be used to write code.
* Learn best-practices for creating simulation workflows that are both scalable and repeatable.

# CTS Exercise

## Trial Design

* Details summarized in `resources/case_summary.md`

## Rationale

* The original case study chose 6mg PO q24h because it provided a reasonable balance of target attainment (76%) and toxicity (G3 AE; 30%).
* However, all subjects were given the same dose of PF06 without an opportunity to modify their dose based upon either PD response (SDMA or PLT).
* It's possible that allowing for dose modification could increase the probability of target attainment while further minimizing the risk of serious adverse events.
* Note: this is a commonly encountered, difficult-to-answer question from Phase 1B/Phase 2 drug development.

## Decision
* To use, or not to use adaptive dosing for subjects receiving PF06?

## Key Questions
1. What are the predicted outcomes (safety, efficacy) for 4-8mg PO q24h regimens without dose adjustment?
2. Can the predicted benefit/risk profile be improved by starting at 6 mg PO q24h while allowing for dose adjustment based upon outcomes?
3. Would a lower starting dose (4 mg PO q24h) in combination with dose adjustment further alter the predicted benefit/risk profile?
4. Would early safety evaluation (cycle day 7) in addition to cycle day 15 prevent subjects from experiencing more severe AEs?
