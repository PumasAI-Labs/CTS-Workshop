
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

