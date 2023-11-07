##################################################################
# PD-Safety (Platelets) Initial Estimates
##################################################################
#=
Fixed Effects   θ       Estimate    Units
tvmtt           1       100         hr
tvslope         2       0.003
tvgamma         3       0.1
tvplt0          4       200         10⁹/L

Random Effects  CV%     VAR
IIV-Slope       -       -
IIV-Gamma       -       -
IIV-PLT0        -       -
RUV (exp)               0.1

Correlation     r       COV [cov = r * sqrt(var1*var2)] #* included for reference, not in model
Slope-Gamma             0.01 
Slope-PLT0              0.01
Gamma-PLT0              0.01
=#

(; 
    mdl = @model begin

        @param begin        
            # Safety (Platelets)
            tvmtt ∈ RealDomain(lower = 0.0001, init = 100)
            tvslope ∈ RealDomain(lower = 0.0001, init = 0.003)
            tvγ ∈ RealDomain(lower = 0.0001, init = 0.1)
            tvcirc0 ∈ RealDomain(lower = 0.0001, init = 200)

            ωslope ∈ RealDomain(lower = 0, init = 0.2)
            ωγ ∈ RealDomain(lower = 0, init = 0.2)
            ωcirc0 ∈ RealDomain(lower = 0, init = 0.2)
            σ²plt ∈ RealDomain(lower=0.0001, init = 0.1)
        end

        @random begin
            ηslope ~ Normal(0, ωslope)
            ηγ ~ Normal(0, ωγ)
            ηcirc0 ~ Normal(0, ωcirc0)
        end

        @covariates tdd freqn cli vci qi vpi kai fsi

        @pre begin
            # PK
            cl = cli
            vc = vci
            q = qi
            vp = vpi
            ka = kai

            # Safety
            mtt = tvmtt
            ktr = 4/mtt
            kprol = ktr
            kcirc = ktr
            slope = tvslope * exp(ηslope)
            γ = tvγ * exp(ηγ)
            circ0 = tvcirc0 * exp(ηcirc0)
        end

        @dosecontrol begin
            # F is both time- and dose-dependent 
            fs = fsi
            bioav = (; depot = fs)
        end

        @init begin
            prol = circ0
            tran1 = circ0
            tran2 = circ0
            tran3 = circ0
            circ = circ0
        end

        @dynamics begin
            # PK
            depot' = -ka*depot
            central' =  ka*depot - (cl+q)/vc*central + q/vp*peripheral
            peripheral' = q/vc*central - q/vp*peripheral
            
            # Drug effect on Platelets (Friberg)
            prol' = kprol*prol * (1-(slope*central/vc)) * (circ0/(circ+1))^γ - ktr*prol
            tran1' = ktr*prol - ktr*tran1
            tran2' = ktr*tran1 - ktr*tran2
            tran3' = ktr*tran2 - ktr*tran3
            circ' = ktr*tran3 - kcirc*circ
        end

        @derived begin
            # Platelets
            plt ~ @. LogNormal(log(circ), sqrt(σ²plt))
        end

    end
)