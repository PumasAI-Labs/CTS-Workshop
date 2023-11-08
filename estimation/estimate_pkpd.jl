##################################################################
# Load Packages
##################################################################
using Pumas, PumasPlots, PumasUtilities
using DataFramesMeta, Dates, CSV, Serialization
using CairoMakie, AlgebraOfGraphics

##################################################################
# Comment Key
##################################################################
#=
Suggest adding the Better Comments extention
! pay special attention
? question for someone else (query)
* worth nothing (highlight)
TODO: thing that needs to be done but isn't broken
FIXME: thing that needs to be fixed that may affect script
// ignore line
=#

##################################################################
# Estimate PK Params
##################################################################
# import datset
#//trialdf = deserialize("data/trial_data.jls")
trialdf = CSV.read("data/trial_data.csv", DataFrame; stringtype = String)

# import pk estimation model
#* string path in include() is based on location of current file, not result of pwd()
pkmdl = include("models/pk.jl").mdl

# create Population for fitting
pkpop = @chain trialdf begin
    # pumas won't allow evid=0 and dv=0 or dv=missing; error on fit unless these rows are removed
    # took care of this by simulating at 0.001 instead of 0, but keep it in mind for future datasets
    #//filter(df -> !(df.evid == 0 && df.time == 0), _) # uncomment to run
    #* PLT was collected on Day 15 when Cycle > 1 while PK and SDMA weren't. This means dv/sdma are
    #* missing at those timepoints and need to be removed prior to fitting
    filter(df -> !ismissing(df.dv) || df.evid == 1, _)
    read_pumas(
        _,
        observations = [:dv],
        covariates = [:tdd, :freqn]
    )
end

# check whether first step of estimation process will execute successfully
findinfluential(
    pkmdl,
    pkpop,
    init_params(pkmdl),
    Pumas.FOCE()
)

# fit model
pkfit = fit(
    pkmdl,
    pkpop,
    init_params(pkmdl),
    Pumas.FOCE()
)

#* dataframe of pk values with posthoc pk param estimates from inspect() used for sequential fitting
pkdf = @chain DataFrame(inspect(pkfit)) begin
    #* id in pkfit is a STRING and must be converted back to Int64 to match trialdf for join
    transform(:id => ByRow(i -> parse(Int64, i)); renamecols = false)
    select(:id, :evid, :time, :cl => :cli, :vc => :vci, :q => :qi, :vp => :vpi, :ka => :kai, :bioav_depot => :fsi)
    leftjoin(trialdf, _, on = [:id,:time,:evid])
    sort([:id, :time, order(:evid, rev = true)])
end


##################################################################
# Estimate PD (SDMA) Params
##################################################################
#* import sdma NTP which has keys for model and initial params!
#* differs from how PK was imported to specify initial params separately
sdma = include("models/sdma.jl")

# create Population for fitting
# ? this isn't returning a Population, just a vector of subjects, why?
sdmapop = @chain pkdf begin
    # pumas won't allow evid=0 and dv=0 or dv=missing; error on fit unless these rows are removed
    # took care of this by simulating at 0.001 instead of 0, but keep it in mind for future datasets
    #//filter(df -> !(df.evid == 0 && df.time == 0), _) # uncomment to run
    #* As above, SDMA was collected at fewer timepoints than PK and because all obs come from the same
    #* dataframe the missing values need to be filtered out before calling read_pumas
    filter(df -> !ismissing(df.sdma) || df.evid == 1, _)
    read_pumas(
        _,
        observations = [:sdma],
        covariates = [:tdd, :freqn, :cli, :vci, :qi, :vpi, :kai, :fsi],
        # ? Do the individual post-hoc estimates need to be treated as time-varying? 
        covariates_direction = :right
    )
end;

# check whether first step of estimation process will execute successfully
#! Remove outer #= =# to run
#=
findinfluential(
    sdma.mdl,
    sdmapop,
    sdma.params1,
    Pumas.FOCE()
)
=#

# fit model
#* not use of sdma.mdl and sdma.params1 instead of init_params(sdma.mdl)
sdmafit = fit(
    sdma.mdl,
    sdmapop,
    sdma.params1,
    Pumas.FOCE()
)

##################################################################
# Estimate PD (Platelets) Params
##################################################################
# import platelet model
pltmdl = include("models/platelets.jl").mdl

# create Population for fitting
# ? As above, this isn't returning a population, it's a vector of subjects
pltpop = @chain pkdf begin
    # pumas won't allow evid=0 and dv=0 or dv=missing; error on fit unless these rows are removed
    # took care of this by simulating at 0.001 instead of 0, but keep it in mind for future datasets
    #//filter(df -> !(df.evid == 0 && df.time == 0), _) # uncomment to run
    #* Same issue regarding missing observations as above
    filter(df -> !ismissing(df.plt) || df.evid == 1, _)
    read_pumas(
        _,
        observations = [:plt],
        covariates = [:tdd, :freqn, :cli, :vci, :qi, :vpi, :kai, :fsi],
        # ? Do the individual post-hoc estimates need to be treated as time-varying? 
        covariates_direction = :right
    )
end;

# check whether first step of estimation process will execute successfully
#! Remove outer #= =# to run
#=
findinfluential(
    pltmdl,
    pltpop,
    init_params(pltmdl),
    Pumas.FOCE()
)
=#

# fit model
pltfit = fit(
    pltmdl,
    pltpop,
    init_params(pltmdl),
    Pumas.FOCE()
)


##################################################################
# Combine and Export Final Paramters Estimate for Simulation
##################################################################
#* coef(fpm) gives NamedTuple of final param estimates
#* "Comprehension" [fxn(x) for x in vector] always returns an array
#* merge() used to combine multiple ntps but first need them out of the array
#* Splat operator (...) converts [ntp1, ntp2, ntp3] into ntp1, ntp2, ntp3
final_estimates = merge([coef(fpm) for fpm in [pkfit, sdmafit, pltfit]]...);

#* export final_estimates for use in simulations
CSV.write("simulation/template/final_estimates.csv", DataFrame([final_estimates]));


##################################################################
# Export Fits
##################################################################
#=
#! Remove outer #= =# to run
# parent out directory based on current UTC datetime
OUTDIR = joinpath("estimation/fits/",string(now(Dates.UTC))[begin:end-4]);

# export fits and key diagnostics
#* CairoMakie needs to be loaded for save function to work
for (i, j) in zip([pkfit, sdmafit, pltfit], ["pk", "sdma", "plt"])
    @info "Starting $j export!"
    mkpath(joinpath(OUTDIR, j))
    
    try
        CSV.write(joinpath(OUTDIR,j,j*"_inspect.csv"), DataFrame(inspect(i)))
    catch e
        @info "Could not generate CoefTable!"
    end
    
    # infer step
    try
        CSV.write(joinpath(OUTDIR,j,j*"_coeftable.csv"),coeftable(infer(i)))
    catch e
        @info "Could not generate CoefTable!"
    end

    #gof panel
    try
        save(joinpath(OUTDIR,j,j*"_gof.png"), goodness_of_fit(inspect(i, nsim=200)))
    catch e
        @info "Could not generate GOF panel!"
    end

    #vpc
    try
        save(joinpath(OUTDIR,j,j*"_vpc.png"), vpc_plot(vpc(i; prediction_correction=true)))
    catch e
        @info "Could not generate VPC!"
    end

    #serialize fit
    try
        serialize(joinpath(OUTDIR,j,j*".jls"), i)
    catch e
        @info "Could not serialize fit!"
    end
end
=#
