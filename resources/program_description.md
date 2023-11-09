# Folders
```
DATA                            (read only; estimation dataset)
ESTIMATION                      (scripts for estimation)
    FITS                        (subfolders named using datetime and contain individual fits)
        2023-10-09T19:55:55
            PK
            SDMA
            PLT 
    MODELS                      (individual model files)
RESOURCES                       (workshop documentation and resources for further study)
RESULTS                         (subfolders named using datetime and contain key plots and tables; name matches RUNS entry)
    2023-10-09T20:08:30
SIMULATION                      (scripts for simulation and post-processing)
    RUNS                        (subfolders named using datetime and contain individualized runs in semi-m5 format)
        2023-10-09T20:08:30     (self-contained folder for each simulation that is copied from the template and preserved going forward)
    TEMPLATE                    (all new sims start with this folder being copied and renamed using the datetime convention above)
        MODELS                  (combined pkpd model file for simulation)
        PATIENTS                (not used in this configuration, but would normally contain patient data for simulation)
        UTILS                   (contains all sim function files, validation files, and custom css file that can be modified for reporting)


```

# Execution

1. Set working directory to parent CTS folder.
2. Verify that `trial_data.csv` available on `data` folder.
3. Run `estimation/estimate_pkpd.jl`
4. Review key diagnostic plots found in `estimation/fits/datetime_run_was_started`.
5. In REPL, type `include("simulation/setup_sim_run.jl")`.
6. Go to newly created folder in `simulation/runs/datetime_setup_was_called`.
7. If running locally, edit and run `simulation/runs/datetime_setup_was_called/cts_local.jl`.
8. Verify that `OUTDIR` remain unchanged and corresponds to `DateTime` folder of current run.
9. Open `simulation/runs/datetime_setup_was_called/postprocess_cts.jl` and either run interactively or run entire script (alternatively: can also use `include()` as above to run entire file assuming `OUTDIR` remains unchanged.)
10. Can use `simulation/runs/datetime_setup_was_called/output_summary.jmd` to get a html document with key outputs by running the following in the REPL
```
using Weave;

weave("simulation/runs/datetime_setup_was_called/output_summary.jmd", mod=Main)
```