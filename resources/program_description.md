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