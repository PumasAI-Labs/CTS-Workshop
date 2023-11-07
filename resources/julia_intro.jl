#=
Author: Haden Bunn
Description: This script is a collection of notes that I've added to each time I've encountered and overcome challenges in my code. Not a full tutorial, but should pair well with the basics course we offer.

=#

typeof()
varinfo() # lists all variables in current workspace

##################################################################
# Numbers
##################################################################

# integer
typeof(1)

# float
typeof(1.0)

# Int to Float
convert(Float64, 1)
float(1)

# Float to Int
convert(Int64, 1.0)
Int(1.0)

# basic equalities work as expected between types
1 == 1.0

# fail the identity test (===), which says "these 2 values are the same and are of the same type
1 === 1.0

# float logic can be weird when math gets invovled
# 0.1 + 0.2 = 0.3, right?
0.1 + 0.2 == 0.3 # FALSE, wait what?
# check it without the equality and see that, from Julia's perspective, 0.1 + 0.2 isn't 0.3
0.1 + 0.2 # keep this in mind when using conditional logic

# round number to x decimal (here its 1)
round(3.135, digits = 1)
# can also force it to round up or down if needed
round(3.135, digits = 1, RoundUp) # rounds up
round(3.135, digits = 1, RoundDown) # rounds down

# large integers can be hard to read, all of these are equivalent
1E6 == 10^6 == 1000000 == 1_000_000 # true

# check if even or odd
iseven(1)
isodd(3)

# '/' operator always returns a float
4/2

# "div" operator ÷ ('\div') gives just the whole number portion of the result
5 ÷ 2

# equivalent to div()
div(5,2)

# for the remainder can use rem()
rem(5,2) # equivalent to the modulo operator (%)
5 % 2

# Modulo can be useful when checking if x is a multiple of y
# if the result is 0, then x is a multiple of y
10 % 2 # 0, so is a multiple of 10 
10 % 6 # >0 not a multiple of 10


##################################################################
# Strings
##################################################################

# single quotes (' ') and double quoutes (" ") aren't interchangeable
'a' # this is a character
#'abc' # FAILS, this isn't allowed
"abc" # success!

# string operations are case-sensitive
"Pumas" == "PUMAS" #false

# string to number
parse(Int64, "1")
parse(Float64, "1")

# you can use tryparse if you're not sure that all the values can be converted to numbers
# returns nothing if can't be parsed
tryparse.(Int64, ["1", "one"])

# you can repeat strings
s1 = "ha"
s1^3 # i thought it was funny :)
repeat(s1, 3)

# you can concantenate/join/combine strings using * or string()
s1 = "Pumas "
s2 = "is "
s3 = "Awesome!"

# neither automatically add spaces
s1 * s2 * s3
s5 = string(s1,s2,s3)

# string interpolation ($) lets you use variable values in strings
# useful for error or info messages
n1 = 20
n2 = 5
cov = "weight"

println("There are $(n1+n2) patients total, but $n2 are missing $cov measurements.") # basic string interpolation, calculations are in $()
println("There are ", n1+n2, " patients total, but ", n2, " are missing ", cov, " measurements.") # also works but harder to read

# as an info statement
@info "There are $(n1+n2) patients total, but $n2 are missing $cov measurements."


##################################################################
# String Indexing and Manipulation
##################################################################

# Strings are a collection of characters which means that, unlike other primitive data types they 
# can be indexed like tuples and arrays

s = "Pumas is Awesome!"

s[1]
s[2:5]
s[11:-1:6] # characters 11 through 6 in reverse order

typeof(s) # string
typeof(s[1]) # character

# look up a string within a string
occursin("Pumas", s)

# replace elements using pair old => new syntax
replace(s, "Awesome" => "INCREDIBLE")

# convert string into an array with each element being a char
collect(s)

# split string into an array of substrings with element string
split(s)

# split string into an array of substrings with element string at the space 
split(s1, " ")

# convert an array of string elements into a string
join(["a","b","c"], " ")
# you can also specify different delimiters for each elements
join(["a","b","c"], ", ", " and maybe ")

# like tuples, strings are immutable
s[1] = 'J' # will error

# can get around that using *, join, or replace
'J' * s[2:end]
join(["J", s[2:end]])
replace(s, "P" => "J")

# you can also reverse the order of a string
reverse(s)



##################################################################
# Regular Expressions
##################################################################

# This part is admittedly a little advanced, but incredibly powerful and worth glancing
# over just so you know it exists as an option. It's all about pattern matching 
# and extracting info from messy data
#=
1. search "regex tutorial" and pick a vid  with >500k views and < 1hr long (this topic is SUPER indepth, but don't get stuck in a deep dive, its not necessary at this point)
2. use an online tool to try it out; I like this one: https://regex101.com/
=#

# say you have a dataframe column which drug names in it; remember that thing about case sensitivity?
drugs = ["vancomycin", "Vancomycin", "VANCOMYCIN"]

# this only gives you the first entry which isn't what we want, since all 3 entries are vancomycin
filter(d -> occursin("vanc", d), drugs)

# you either have to normalize the case of all the entries using lowercase() or uppercase()
filter(d -> occursin("vanc", lowercase.(d)), drugs)

# or you could use a regex (r"" indicates a regex, the i in r""i is a flag to ignore case when matching)
filter(d -> occursin(r"vanc"i, d), drugs)

# here's another example of what you can do
# say you have a field from an database that lists age as a string ("65y236d")
# which would be inconvenient to separate or perform calculations on, but
# regex will allow you to extract the numbers from the string
# the comprehension below will show you what's possible, don't sweat the details for now, just know it's 
# here and come back after you've explored a bit
[parse(Int,x.match) for x in eachmatch(r"\d+", "65y236d")]


##################################################################
# Dictionaries
##################################################################

# pros: flexible and mutable 
# cons: not indexed which means can't select elements by index number, sort the data, or select a range of data

# create a dictionary
# Dict(key => value)
# keys can be number (1), string ("one"), symbol (:one), others?
# values can be WIDE variety of things (numbers, strings, functions, dataframes, etc)
d1 = Dict("A" => 10, "B" => 100, "C" => 1000)
d2 = Dict("A" => 20, "D" => 200, "E" => 2000)

# all keys
keys(d1)

# all values
values(d1)

# can merge dictionaries
# note, if there's a conflict in keys, the value of the LAST dictionary listed is used
# note the conflict in key A and that value 20 is used in merge, not the 10 in d1
merge(d1, d2)

# add a new key/value pair to d2
push!(d1, "K" => 10000)
# this format also works
d2["L"] = 20000

# permanently remove a key and its value
pop!(d1, "K")
# can also do
delete!(d2, "L")

# is A a key in d1?
"A" in keys(d1) # ∈ also works

# is 100 NOT a value in d1?
100 ∉ values(d1)

# loop through all key/value pairs in Dict and all 5 to each
for k in keys(d1)
    d1[k] = d1[k] + 5
end

# or could do it like this
for (k, v) in d1
    d1[k] = v + 5
end

##################################################################
# Tuples
##################################################################

# pros: very efficient way to collect and index data of any type
# cons: immutable

t1 = () # empty tuple

t2 = (1, ) # comma after single element is REQUIRED

# elements can be multiple data types
t3 = (1, 1.0, :red, false, 'A')

typeof(t3) # shows type tuple and all of the datatypes it contains

# indexing begins at 1 for first entry in tuple and goes up from there 
t3[1] # 1
t3[2] # 1.0
t3[end] # last value
t3[begin] # first value
t3[1:3] # elements 1 to 3
t3[3:end] # all elements beginning at 3 to the last element
t3[2:end-1] # all elements beginning at 2 to the second to last element
t3[1:2:5] # all elemenets between 1 and 5 skipping in increments of 2 (ie 1,3,5) 

# can COMBINE tuples
t4 = (1,2,3)
t5 = (4,5,6)

# a tuple of tuples
t6 = (t4, t5) 
typeof(t6) # a tuple of 2 tuples each with elements of datatype Int64 

# to MERGE tuples use the splat (...) operator
t7 = (t4..., t5...)

# 1 is a value in t7
1 ∈ t7

# 1 is not in t7
1 ∉ t7

# sum all the elements of tp6
sum(t7)

# add 10 to all elements of tp6
t7 .+ 10

# note that t7 is unchanged
t7

# other built in functions
minimum(t7)
maximum(t7)
extrema(t7)


# interesting use case for tuples
# can you swap the values of 2 variables (x, y) without creating an interim variable (z)?
# set x,y 
x = 100
y = 250
# store x
z = x
# swap x and y; x and y both 250 now
x = y
# change y to previous val of x
y = z
x
y

# or use a tuple
x = 100
y = 250
(x, y) = (y, x)


##################################################################
# NamedTuples
##################################################################

#pros: similar to dictionaries in that they use a name/value pair (keys are stored as type "Symbol" instead of string)
#cons: immutable, can use indexing but no ranges

# creating named tuples similar to tuples with addition of a key assignment
nt = (df = "patients", n_patients = 50, idcol = :subjid)

# object of type NamedTuple with 3 keys and values of type String, Int64 and Symbol
typeof(nt)

# can also create them using shorthand
df = "patients"
n_patients = 50
idcol = :subjid
# this is super handy for creating nts progammatically
nt = (; df, n_patients, idcol)

# can still use indexing
nt[1]

# CANNOT use RANGES
nt[1:2] # will error out

# can index using key symbol
nt[:df]

# or can use dot syntax
nt.df

# lists the keys, values, and value types
dump(nt)

# lists the keys
keys(nt)

# lists the values
values(nt)

# lists the key/value pairs of the ntp
pairs(nt)


##################################################################
# Arrays
##################################################################

# can contain any combination of datatypes within the same array
# in math, you have:
#   scalars (single element)
#   vectors (1D)
#   matrices (2D),
#   tensors (collection of elements in arbitrary number of dimension)
# in julia, ALL of the above are ARRAYS
# multi-dimensional arrays are listed as (row x col)

# empty array
a = []

typeof(a) # Array{Any,1} the 1 means that by default a is a 1D array

# scalar (vector w/ single element)
s = [1] # example of a scalar which in julia is a 1D array with 1 element

# column vector (cv), 1D array with 1 column containing an arbitraty number of elements
cv = [1,2,3]

typeof(cv) # Array{Int64,1}

# row vector (rv), 2D array with 1 row containing an arbitray number of elements
rv = [1 2 3] #1x3 array

typeof(rv) # Array(Int64,2) note the 2 for a 2D array 

# matrix, 2D array with an arbitray number of rows and cols
m = [1 2 3; 4 5 6] # 2x3 array

typeof(m) # Array(Int64,2)

# rand generates a number between 0 and 1
a1 = rand(4,2,3) # 3D array with 4 rows, 2 columns, and 3 layers 

typeof(a1) # Array{Float64, 3}

# for 1D arrays (scalars, vectors) you can index using
s[1]
cv[2]

# for 2D arrays
m[1,2] # row column pair (row 1, col 2)
m[:,3] # all rows in col 3
m[2,:] # row 2 all columns
m[1:2,2:3] # rows 1, 2; cols 2, 3
m[end, :] # last row all cols
m[:, end] # last col all rows

# multidimensional arrays also use linear indexing that is
# in COLUMN MAJOR ORDER ()
m
m[5] # using COLUMN MAJOR ORDER; should be 3

m[:] # all elements in array in the sequence in which they are stored in memory, regardless of shape

# update value of row 1 col 2 to 9
m[1,2] = 9

# basic math works as well
cv[1] + 1

# sum works as do minimum and maximum and extrema
sum(m)

# can operate on entire array using broadcasting
cv .* 2

# row by col dimensions of an array
size(m)

# number of elements in array
length(m)

# element type in array
eltype(m)

# transpose so that first col becomes first row
# Does NOT maintain column major order
# Does NOT alter in place
transpose(m) # can also call using m'

# will also reshape the array int 3 rows and 2 cols but it DOES maintain column major order
# does NOT alter in place
reshape(m, 3,2)

# only works on column vectors
sort(cv, rev=true)

# add 5 to end of cv
push!(cv, 5)

# remove last element from cv
pop!(cv)

# quickly create arrays
fill(π, 5, 5) # 5x5 matrix of pi
zeroes(Int64, 3,5) # 3x5 matrix of zeroes as Int64
ones(Float64, 6,5) # 6x5 matrix of ones as Float64
trues(5) # cv bitvector of "trues"
falses(1,5) # rv bitmatrix of "falses"

# other array functions
A = [1, 2, "red"]
B = [2, 3, "blue"]

# is element in array
1 in A # true 

# create array of unique elements of A/B
union(A, B)

# create array of common elements of A/B
intersect(A, B)


# Array CONCATENTATION
# using a comma will give array of arrays
[A, B] 

# using semicolon will give a 1D vertical array (column vector) of concatenated elements
[A; B] # equivalent to vcat(a,b)

# using a space gives a horizontal concatenation
[A B] # equivalent to hcat(a, b)


##################################################################
# Arrays and Memory
##################################################################

# try this experient, the outcome is IMPORTANT
a = 1
b = a
a = 2

# Value of a is 2 now, but what do you think the value of b is at this point?
# The value of b is STILL 1 because in reality b is just the name for a place in memory, it won't update until you tell it to
b # unchanged!


# ARRAYS BEHAVE DIFFERENTLY!!!
# when you set b = a, you're creating an ALIAS "b" for vector "a"
# In other words, b is NOT stored in a separate memory location from a, it's simply pointing to where a is stored
a = [1,2,3]
b = a
a[1] = 100
b # changed!!


# to create a true "copy" of a, you can use copy()
a = [1,2,3]
b = a
c = copy(a) # this creates a SHALLOW copy, can use deepcopy() 

# this will update a and b but NOT c
b[2] = 100 
# this will only update c, not a or b
c[2] = 1000 


##################################################################
# Choosing the Right Container
##################################################################

# create 4 representative containers with same data
# dictionary
d = [1 => "apple", 2 => "banana"]
# tuple
t = ("apple", "banana")
# namedtuple
nt = (one = "apple", two = "banana")
# array
a = ["apple", "banana"]

#=
Using varinfo() you can see the relative size of each of variable (see below)
    dictionary (483b) > array (83b) > ntp/tp (43b)

So, in general you can say that:
1. Dictionaries offer a lot of flexibility, but consume the most memory
2. Tuples are the most memory efficient but are also the least flexible. NTPs offer a few more options without an additional memory cost but require more key strokes
3. Arrays offer a balance between flexibility and memory efficiency which makes them the "workhorse" data structure (they can hold almost anything and do it efficiently)
=#


##################################################################
# Random Thought
##################################################################

# rand() is a super useful tool for filling collections with random data

# single random number from a uniform distribution b/t 0 and 1
rand()

# col vector with 5 elements
rand(5)

# can specify type and give multiple dimensions
rand(Float64, 5, 5)
rand(Int64, 5, 5, 4)

# can use bool
rand(Bool, 5, 5)

# can provide a range of numbers
rand(1:100, 5, 5)
# can provide a range AND a step
rand(10:10:100, 5, 5)


##################################################################
# Custom Functions
##################################################################

# can assign a builtin function to a variable by omitting the ()
foo = iseven
foo(3)
iseven(3)


# custom function
function printlist(items)
    for item in items
        println(item)
    end
end


# Documenting functions
# documentation shown in the help (?) menu is a version of markdown
# starts/end with """
# jldoctest displays the contents between ``` the way it would appear in the REPL

begin
    """
    is_even(x) -> Bool

    Return `true` if `x` is an even number.
    Return `false` if `x` is an odd number.

    # Example
    ```jldoctest

    julia> is_even(3)
    false

    julia> is_even(4)
    true
    ```
    """

    function is_even(x)
        return x % 2 == 0
    end
end


# Multiple dispatch 
# Allows Julia to choose which method of a function is most appropriate.
# Works based on number of argument and types of ALL arguments, in other languages, dispatch occurs based on the first argument
# WARNING: you don't need to set up separate methods for every function, it's a balance of being too vague or too specific; judgement call

# tells you all methods available to a function
methods(+)

# tells you which method of a function julia is calling
@which 1 + 1
@which 1.0 + 1.0
@which 1.0 + 1

# set multiple methods by using the type assertion operator (::)
# if unspecified, it's really just x::Any
function methodtest(x, y)
    println("This is the default method for $x and $y.")
end

# Integer is an ABSTRACT type of the PRIMITIVE types of integer (eg, Int32, Int64)
# Always use AbstractTypes instead of Primitives
function methodtest(x::Integer, y::Integer)
    println("$x plus $y is", x + y)
end

methodtest(1, 2)
methodtest(1.0, 2.0)

# note that AbstractFloat is the ABSTRACT type of PRIMITIVE types of float (eg Float32, Float64)
function methodtest(x::AbstractFloat, y::AbstractFloat)
    println("$x times $y is", x * y)
end

# AbstractString is the ABSTRACT type of String
function methodtest(x::AbstractString, y::AbstractString)
    println("""Concatenating $x and $y yields "$x $y" """)
end

# all methods for methodtest
methods(methodtest)

# which method of methodtest is being used
@which methodtest(1, 2)

##################################################################
# Composite Data Types
##################################################################
#=

* There are 3 datatypes in Julia: Primitive, Abstract, Composite
* Composite types are "USER DEFINED" datatypes and they are a collection of named fields that can contain a value
* Like tuples, they are IMMUTABLE by default, but unlike tuples you can create mutable composite types

They are created using the syntax below:
1. Use camelcase for type name
2. x,y,z are the named fields
3. When asserting types, use the abstract type, not primitives


struct MyType
    x
    y::Integer
    z::AbstractFloat
end

OR

mutable struct MyMutType
    x
    y::Integer
    z::AbstractFloat
end

=#

# define composite type
struct TrialPatient
    id # implied ::Any
    group::Integer
    weight::AbstractFloat
end

# this will be of type DataType
typeof(TrialPatient) # DataType

# view all named fields in type; they are of type Symbol
fieldnames(TrialPatient)

# to populate the type with values can use parenthesis like a function
# when a type is applied like a function it's referred to as a CONSTRUCTOR
# note this is similar to how a dictionary is specified but you don't have to provide a key because the named fields are already included
pt = TrialPatient("subj1", 1, 65.6)

typeof(pt) # TrialPatient

# access values using dot syntax
pt.id
pt.group
pt.weight

# as stated before, values can't be changed
pt.group = 2 # FAILS

# define composite type
mutable struct MutTrialPatient
    id # implied ::Any
    group::Integer
    weight::AbstractFloat
end

# create mutable patient
mpt = MutTrialPatient("subj1", 1, 65.6)

# update group
mpt.group = 2

# comparing performance again

a = ["subj1", 1, 65.6]
d = Dict(:id => "subj1", :group => 1, :weight => 65.6)
t = ("subj1", 1, 65.6)
nt = (id = "subj1", group = 1, weight = 65.6)

# call varinfo to compare
varinfo()

#=
As before:

Dict(485) > Array(93) > mpt/pt(53) > ntp/tp(37)

1. dictionary takes of the most memory
2. tuples take up the least but are the least flexible
3. Composite type is more than the tuples but not as much as the dictionary and a lot less than the array
4. Composite types are more flexible than tuples and take up alot less memory than a dictionary
5. There may be a (small?) performance hit using a mutable struct, would need to be assessed in realtime during project (use caution)
=#