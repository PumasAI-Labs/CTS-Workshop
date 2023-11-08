# Day 1 (30 minutes)

## Setup
* Download zip file and drag into environment
* Set working directory (critical!)
* My IDE has some customizations, will go over quickly if come early on Day 2

## README.md

* Introduction section

## program_description.md

* Talk about folder structure
* Highlight resources folder (especially julia introduction)

## Estimation

* Highlight entire file and run, then discuss while running
* Estimation step is abbreviated here for time, full process in detail in Onboard materials

### Layout
* Sequential approach with separate model files, each with a NamedTuple containing model and params
* Initial estimates can be defined in the model block or provided separately (both approaches shown)
    + Having in model is convenient, but has some computational overhead
    + Having external allows flexibility but can be confusing if not managed correctly (ie kept in a separate ntp)

### Workflow (PK)
* Import dataset from CSV
* Use `include` to load model from separate file
    + For PK only the model is loaded
* `find_influential` is a good way to identify if there's any model misspecification or data issues (NaN or Inf)
* Fit the model
* Combine post-hoc estimates from PK model with original df so that they can be carried forward as covariates during the estimation step for the PD models
* Combine and save final parameter estimates for import into the integrated simulation model
* Talk about automatic export of key diagnostics and how to save fits (to serialize or not)


