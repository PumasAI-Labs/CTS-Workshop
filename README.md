# Clinical Trial Simulation Workshop

# Background

## Reference
* PK/PD model-informed dose selection for oncology phase I expansion: Case study based on PF-06939999, a PRMT5 inhibitor. doi: 10.1002/psp4.12882

## Overview
* Use PK/PD modeling to select recommended dose (PF06) for expansion based on first in patient data collected from a Phase 1 dose escalation trial that included 28 patients with solid tumors.
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

# Exercise

## Rationale

For each simulation in the manuscript, all subjects were given the same dose of PF06 without an opportunity to modify their dose based upon either PD response. It's possible that allowing for dose modification could increase the probability of target attainment while further minimizing the risk of serious adverse events. Realistically, it's a little early in the drug's development cycle to consider these questions, but they provide an excellent justification for performing a more advanced simulation.

## Key Questions

1. Can the results of the original simulation (specifically 4-8mg PO q24h) be reproduced in Pumas?
2. Would starting all patients at the lower end of the simulated range (4mg) and allowing for dose modification based upon PD response further improve both safety and efficacy metrics?
3. The first follow-up for the original simulations was at cycle day 15. Would an earlier follow-up at cycle day 7 with the potential to taper the starting dose prevent subjects from experiencing more severe AEs?