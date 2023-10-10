##################################################################
# Estimate PK Params
##################################################################

# import datset
trialdf = deserialize("trial_data.jls")

# import pk estimation model
pkmdl = include("pk.jl").mdl

# create Population for fitting
pkpop = @chain trialdf begin
    # pumas won't allow evid=0 and dv=0 or dv=missing; error on fit unless these rows are removed
    # !FIXME: followup about this and get the specifics
    filter(df -> !(df.evid == 0 && df.time == 0), _)
    # keep only non-missing obs
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

# dataframe of pd value with posthoc pk param estimates for sequential fitting
pkdf = @chain DataFrame(inspect(pkfit)) begin
    select(:id, :evid, :time, :cl => :cli, :vc => :vci, :q => :qi, :vp => :vpi, :ka => :kai, :bioav_depot => :fi)
    leftjoin(trialdf, _, on = [:id,:time,:evid])
    sort([:id,:time,order(:evid, rev = true)])
end

##################################################################
# Estimate PD (SDMA) Params
##################################################################

# import sdma estimation model
sdmamdl = include("efficacy.jl").mdl

# create Population for fitting
# !FIXME: this isn't returning a Population, just a vector of subjects?
sdmapop = @chain pkdf begin
    # FIXME! What's the deal with non-zero obs at t=0?
    filter(df -> !(df.evid == 0 && df.time == 0), _) 
    # keep only non-missing obs
    filter(df -> !ismissing(df.sdma) || df.evid == 1, _)
    read_pumas(
        _,
        observations = [:sdma],
        covariates = [:tdd, :freqn, :cli, :vci, :qi, :vpi, :kai, :fi],
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
pltmdl = include("safety.jl").mdl

# create Population for fitting
# FIXME! As above, this isn't returning a population, it's a vector of subjects
pltpop = @chain pkdf begin
    # FIXME! What's the deal with non-zero obs at t=0?
    filter(df -> !(df.evid == 0 && df.time == 0), _)
    # keep only non-missing obs
    filter(df -> !ismissing(df.plt) || df.evid == 1, _)
    read_pumas(
        _,
        observations = [:plt],
        covariates = [:tdd, :freqn, :cli, :vci, :qi, :vpi, :kai, :fi],
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

