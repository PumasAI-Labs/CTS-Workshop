##################################################################
# Load Packages
##################################################################
using Pumas, PumasPlots
using DataFramesMeta, Serialization

##################################################################
# Comment Key
##################################################################
#=
Suggest adding the Better Comments exention
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
trialdf = deserialize("data/trial_data.jls")

# import pk estimation model
#* string path in include() is based on location of current file, not pwd()
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
        # TODO: add time-varying covariate if time permits
    )
end

# check whether first step of estimation process will execute successfully
findinfluential(
    pkmdl,
    pkpop,
    init_params(pkmdl),
    Pumas.FOCE();
    k = length(pkpop)
)

# fit model
pkfit = fit(
    pkmdl,
    pkpop,
    init_params(pkmdl),
    Pumas.FOCE()
)

# dataframe of pk value with posthoc pk param estimates for sequential fitting
pkdf = @chain DataFrame(inspect(pkfit)) begin
    select(:id, :evid, :time, :cl => :cli, :vc => :vci, :q => :qi, :vp => :vpi, :ka => :kai, :bioav_depot => :fi)
    leftjoin(trialdf, _, on = [:id,:time,:evid])
    sort([:id, :time, order(:evid, rev = true)])
end

##################################################################
# Estimate PD (SDMA) Params
##################################################################

# import sdma estimation model
sdmamdl = include("models/sdma.jl").mdl

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
    Pumas.FOCE();
    k = length(sdmapop)
)

# fit model
sdmafit = fit(
    sdmamdl,
    sdmapop,
    init_params(sdmamdl),
    Pumas.FOCE()
)

#=
sdmapop = [Subject(sub; covariates = ic) for (sub, ic) in zip(sdmapop, icoef(pkfit))]
sdmapop = [Subject(sub; covariates = dcp) for (sub, dcp) in zip(sdmapop, dosecontrol(pkfit))]
=#



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
    Pumas.FOCE();
    k = length(pltpop)
)

# fit model
pltfit = fit(
    pltmdl,
    pltpop,
    init_params(pltmdl),
    Pumas.FOCE()
)


##################################################################
# Export Fits
##################################################################
for (i, j) in zip([pkfit, sdmafit, pltfit], ["pk", "sdma", "plt"])
    serialize("estimation/fits/"*j*".jls", i)
end