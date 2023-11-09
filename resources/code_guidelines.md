# Code Guidelines
* Think through what you intend to accomplish and once you have a clear picture use these first principles to get started.

# Data Structures
* There is A LOT more to this topic, but these basic points will get you started.

## Arrays
* Can contain any combination of datatypes within the same array
* Multi-dimensional arrays are listed as (row x col)
* Indexed, mutable

```
a = [1,2,3]
a[1]
a[1] = 100
```

## Dictionaries
* Contain any combination of datatypes in key => value pairs
* Not indexed, but mutable
* Flexibility makes them great for holding complex data but they take up more memory than other types

```
d1 = Dict("A" => 10, "B" => 100, "C" => 1000)
d1["A"]     # works
d1[1]       # fails
d1["A"] = 15
```

## Tuples
* Contain any combination of data types
* Indexed, immutable
* Very efficient when they can be used

```
tp = (1, 1.0, :red, false, 'A')
tp[1]
tp[1] = 15  # fails
```

## NamedTuples
* Similar to dictionaries in that they use a name/value pair but keys are stored a symbols not string
* Indexed (but can't use ranges), immutable

```
# created this way
ntp = (df = "patients", n_patients = 50, idcol = :subjid)

# or this way
df = "patients
npatients = 50
idcol = :subjid

ntp = (; df, npatients, idcol)

ntp[1]                  # works
ntp[1:3]                # fails
ntp[:df]                # works
ntp[1] = "subjects"     # fails
```

## Choosing the Right Container

1. Dictionaries offer a lot of flexibility, but consume the most memory
2. Tuples are the most memory efficient but are also the least flexible. NTPs offer a few more options without an additional memory cost but require more key strokes
3. Arrays offer a balance between flexibility and memory efficiency which makes them the "workhorse" data structure (they can hold almost anything and do it efficiently)


# DRY principle
* If typing it more than twice, turn it into a function

```
a = (5 + 10) * 4
b = a/2

c = (100 + 25) * 4
d = c/2

function f(x1, x2)
    y = (x1 + x2) * 4/2
    return y
end

f(5,10)     # same result as first operation
```

# Modularization
* The trial workflow should be controlled by a single "main" function that calls additional "helper" functions as needed.
* Each trial action (e.g., safety assessment, dose change) should be implemented as a separate function
    + Must also create a mechanism to test/validate each function

```
function mytrial()

    f1()

    f2()

    f3()

    return result

end
```

# DataFrames
* Dataframes are computationally expensive; try to avoid during simulation and convert to DF after.
    + Try to stick with built-in types (named tuples, dictionaries, Pumas constructors), but this isn't always easy
* Dataframes store more than just tabular data which makes the ideal for storing the result of a set of simulations

# Simulation Inputs and Outputs

## Scenario
* A NamedTuple of keyword options that will be used to change how simulations are conducted.
* Allows a single function to perform multiple different simulations without repeating code.

```
# Example only
(
    STARTINGDOSE = 4,
    DAYSOFTHERAPY = 15
)
```
## Trial events (trial_event)
* A NamedTuple that stores key information for each simulated visit

```
# Example only
(
    day = 7,
    pkval = 92.3,
    pdval = 50.1,   
)
```

## Patient
* The "experimental unit" of the simulation
* A dictionary used to store multiple data types.
* Needs to be mutable, so this is the best option aside from a user-defined data type but that's beyond the scope of the current problem.

```
patient = Dict(
    "id" => 1,
    "trialdetail1" => DataFrame,
    "trialdetail2" => Dict("key1" => 1, "key2" => [1,2,3])?
)
```

# Execution

## Flow
* Script will execute one row at a time; write functions to perform small tasks and then tie it all together using standard control-flow
    + for-loops
    + while-loops
    + conditionals

## Pseudo-Code
* Write out what you want to do in words, then figure out how to turn that into code.
* Helps focus your thoughts and more important allows you to clearly communicate what you want to do to more advanced programmers when asking for help.

## Trial and Error
* Start small, get your functions to work, then start to tie them together
* Once you have a working script, test it using a single subject.
* If it works for a single subject, then you can scale it to multiple subjects.

## Aim for Scalable and Repeatable Code
* The same code should be able to handle all of the following:
    + Single subject
    + Population with a single scenario
    + Multiple populations with different scenarios

