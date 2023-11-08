##################################################################
# Set OUTDIR
##################################################################


##################################################################
# Import Model Fit Inspect
##################################################################
# FIXME: should be imported, not done in place
pkidf = DataFrame(inspect(pkfit))
sdmaidf = DataFrame(inspect(sdmafit))
pltidf = DataFrame(inspect(pltfit))


##################################################################
# Helper Functions
##################################################################
function plot_qpc(repq50, q5, q50, q95, refvalue, xlab)

    f = Figure(
        resolution = (1000,1000),
        fontsize = 20
    )

    a = Axis(f[1,1]; xlabel = xlab)
    
    hist!(a, repq50, color = :gray, strokewidth = 1, strokecolor = :black)
    vlines!(a, [q5,q50,q95], color = :black, linestyle = :dash, linewidth = 3)
    vlines!(a, refvalue, color = :lightblue, linestyle = :dashdot, linewidth = 3)

    return f

end


##################################################################
# Combining Profiles
##################################################################
#* goal is create a dataframe that contains all profiles for all sims
#* start by extracting profile from patient dictionary and adding them as col in results df
mysims[!, :profiles] = map(eachrow(mysims)) do r

    # df of individual sims becomes a SimulatedPopulation
    # this way only have to call DataFrame once
    profiles = [pt["profile"] for pt in r.sims]

    # convert sims to df
    df = DataFrame(profiles);

    # convert ids to integer
    df[!, :id] .= parse.(Int64, df.id)

    # add items for filtering later
    df[!, :runid] .= r.runid
    df[!, :skip_cday7] .= r.scenarios.SKIP_CDAY7

    # return combined df
    return df

end;

# combined df of all simulated obs
profiles = reduce(vcat, mysims.profiles);

# convert runid to categorical value for use in summaries
profiles[!, :runlabel] = categorical(profiles.runid);
#? why can't this be converted in place
#//recode!(events.runlabel, 1=>"BLREF",2=>"EARLY6MG",3=>"ADJ4MG",4=>"PUB4MG",5=>"PUB6MG",6=>"PUB8MG")
profiles[!, :runlabel] = recode(profiles.runlabel, [Pair(r.runid,r.labels) for r in eachrow(mysims)]...);


##################################################################
# Qualification DataFrame
##################################################################

qualdf = @chain profiles begin
    filter(df -> df.evid == 0, _)
    filter(df -> df.time == 360, _)
    select(:id, :time, :dv, :sdma, :plt, :cl, :vc, :sdma0, :circ0, :slope)
    transform([:sdma, :sdma0] => ByRow((s,bl) -> 100*(1-(s/bl))) => :sdmaredbl)
end

# add repid for 200 reps, 50 subjects per rep
qualdf[!, :repid] = repeat(1:200, inner = 50);



##################################################################
# Core QPC 
##################################################################

inspectdfs = [pkidf, sdmaidf, pltidf];
coreparams = [
    [:cl, :vc],
    [:sdma0],
    [:circ0, :slope]
];

coreqpc = map(zip(inspectdfs, coreparams)) do (idf, param)

    # FIXME: this needs to be on a df of inspect else it will run inspect each time repeated; costly
    iparams = combine(groupby(idf, :id), first)

    qpcplots = map(param) do p

        # vector of median values for each repid for a given param (p)
        refq50 = combine(groupby(qualdf, :repid), p => (x -> quantile(x, 0.5)) => :q50).q50

        # refq50 quantiles
        q5 = quantile(refq50, 0.05)
        q50 = quantile(refq50, 0.50)
        q95 = quantile(refq50, 0.95)

        # median value from original fit
        refvalue = quantile(iparams[!,p], 0.5)

        plt = plot_qpc(refq50, q5, q50, q95, refvalue, "50th Percentile for "*uppercase(string(p)))

        return plt

    end

    return qpcplots

end

##################################################################
# Derived QPC
##################################################################
#* This section should be interpretted with caution because on 4 subjects
#* in the original dataset received 6mg PO q24h

#! input must be a vector or inner map() will fail
observedvals = [
    [:dv],
    [:sdma],
    [:plt]
];

derivedqpc = map(zip(inspectdfs, observedvals)) do (idf, val)

    # FIXME: this needs to be on a df of inspect else it will run inspect each time repeated; costly
    obsval = filter(df -> df.time == 360.001 && df.evid == 0 && df.tdd == 6 && df.freqn == 24, idf)

    qpcplots = map(val) do v

        # vector of median values for each repid for a given param (p)
        refq50 = combine(groupby(qualdf, :repid), v => (x -> quantile(x, 0.5)) => :q50).q50

        # refq50 quantiles
        q5 = quantile(refq50, 0.05)
        q50 = quantile(refq50, 0.50)
        q95 = quantile(refq50, 0.95)

        # median value from original fit
        refvalue = quantile(obsval[!,v], 0.5)

        plt = plot_qpc(refq50, q5, q50, q95, refvalue, "50th Percentile for "*uppercase(string(v)))

        return plt

    end

    return qpcplots

end

##################################################################
# Endpoint QPC
##################################################################

obsval = filter(df -> df.time == 360.001 && df.evid == 0 && df.tdd == 6 && df.freqn == 24, sdmaidf)
transform!(obsval, [:sdma, :sdma0] => ByRow((s,bl) -> 100*(1-(s/bl))) => :sdmaredbl)

# vector of median values for each repid for a given param (p)
refq50 = combine(groupby(qualdf, :repid), :sdmaredbl => (x -> quantile(x, 0.5)) => :q50).q50

# refq50 quantiles
q5 = quantile(refq50, 0.05)
q50 = quantile(refq50, 0.50)
q95 = quantile(refq50, 0.95)

# median value from original fit
refvalue = quantile(obsval[!,:sdmaredbl], 0.5)

plt = plot_qpc(refq50, q5, q50, q95, refvalue, "50th Percentile for SDMA Reduction from BL")




