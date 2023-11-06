##################################################################
# Load Packages
##################################################################
using Pumas, PumasPlots
using DataFramesMeta, Dates, CSV, Serialization

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
trialdf = deserialize(joinpath(@__DIR__, "../data/trial_data.jls"))

# import pk estimation model
#* string path in include() is based on location of current file, not result of pwd()
pkmdl = include(joinpath(@__DIR__, "models/pk.jl")).mdl

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
        # TODO: add time-varying covariate if time permits
    )
end

# check whether first step of estimation process will execute successfully
findinfluential(
    pkmdl,
    pkpop,
    init_params(pkmdl),
    FOCE()
)

# fit model
pkfit = fit(
    pkmdl,
    pkpop,
    init_params(pkmdl),
    FOCE()
)

# dataframe of pk values with posthoc pk param estimates from inspect() used for sequential fitting
pkdf = @chain DataFrame(inspect(pkfit)) begin
    select(:id, :evid, :time, :cl => :cli, :vc => :vci, :q => :qi, :vp => :vpi, :ka => :kai, :bioav_depot => :fi)
    leftjoin(trialdf, _, on = [:id,:time,:evid])
    sort([:id, :time, order(:evid, rev = true)])
end

##################################################################
# Estimate PD (SDMA) Params
##################################################################
# import sdma estimation model
sdmamdl = include(joinpath(@__DIR__, "models/sdma.jl")).mdl

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
        covariates = [:tdd, :freqn, :cli, :vci, :qi, :vpi, :kai, :fi],
        # ? Do the individual post-hoc estimates need to be treated as time-varying? 
        covariates_direction = :right
    )
end;

# check whether first step of estimation process will execute successfully
findinfluential(
    sdmamdl,
    sdmapop,
    init_params(sdmamdl),
    FOCE()
)

# fit model
sdmafit = fit(
    sdmamdl,
    sdmapop,
    init_params(sdmamdl),
    FOCE()
)

##################################################################
# Estimate PD (Platelets) Params
##################################################################
# import platelet model
pltmdl = include(joinpath(@__DIR__, "models/platelets.jl")).mdl

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
        covariates = [:tdd, :freqn, :cli, :vci, :qi, :vpi, :kai, :fi],
        # ? Do the individual post-hoc estimates need to be treated as time-varying? 
        covariates_direction = :right
    )
end;

# check whether first step of estimation process will execute successfully
findinfluential(
    pltmdl,
    pltpop,
    init_params(pltmdl),
    FOCE()
)

# fit model
pltfit = fit(
    pltmdl,
    pltpop,
    init_params(pltmdl),
    FOCE()
)

##################################################################
# Export Fits
##################################################################
# parent out directory based on current UTC datetime
mkpath(joinpath(@__DIR__, "fits"))
outdir = joinpath(@__DIR__, "estimation/fits/", Dates.format(now(Dates.UTC), "yyyy-mm-ddTHH:MM:SS"))

# export fits and key diagnostics
for (i, j) in zip([pkfit, sdmafit, pltfit], ["pk", "sdma", "plt"])
    @info "Starting $j export!"
    mkpath(joinpath(outdir, j))
    # infer step
    try
        CSV.write(joinpath(outdir,j,j*"_coeftable.csv"),coeftable(infer(i)))
    catch e
        @info "Could not generate CoefTable!"
    end

    #gof panel
    try
        save(joinpath(outdir,j,j*"_gof.png"), goodness_of_fit(inspect(i, nsim=200)))
    catch e
        @info "Could not generate GOF panel!"
    end

    #vpc
    try
        save(joinpath(outdir,j,j*"_vpc.png"), vpc_plot(vpc(i; prediction_correction=true)))
    catch e
        @info "Could not generate VPC!"
    end

    #serialize fit
    try
        serialize(joinpath(outdir,j,j*".jls"), i)
    catch e
        @info "Could not serialize fit!"
    end
end