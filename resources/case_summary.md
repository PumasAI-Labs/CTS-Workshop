# Case Study

## Reference
* PK/PD model-informed dose selection for oncology phase I expansion: Case study based on PF-06939999, a PRMT5 inhibitor. (doi: 10.1002/psp4.12882)

## Overview
* PF06 is a small molecule inhibitor of protein arginine methyltransferase 5 (PRMT5)
* First in patient data collected from a Phase 1 dose escalation trial that included 28 patients with solid tumors.
    + 0.5-8mg PO q12h
    + 0.5-6mg PO q24h
* PD biomarker for "efficacy"
    + SDMA (symmetrical dimethyl-arginine)
        - Catabolic product of PRMT5 activity.
        - Reduction in SDMA has been correlated with tumor response, specifically a 78% reduction in plasma SDMA was shown to correspond with nearly complete inhibition of tumor SDMA.
* PD biomarker for "safety"
    + PLT (platelet count)
        - Thrombocytopenia is the most common adverse event for this class
    + Grade definitions
        - G1 = <100 10⁹cells/L
        - G2 = <75
        - G3 = <50 (bad)
        - G4 = <25 (really bad)
    + 30-35% G3 or above acceptable

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