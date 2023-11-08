##################################################################
# PD-Efficacy (SDMA) Initial Estimates
##################################################################
#=

Fixed Effects   θ       Estimate    Units
tvimax          1       0.9  
tvic50          2       2           ng/mL = μg/L
tvkout          3       0.03        hr⁻¹
sdma0           4       120         ng/mL = μg/L

Random Effects  CV%     VAR         SD            
IIV-SDMA0       20%     -           0.2
RUV (add)       -       0.1         0.316

Correlation     r       COV [cov = r * sqrt(var1*var2)] #* included for reference, not in model
CL-Vc                   0.01 
=#

(; 
    mdl = @model begin

        @param begin
            # Efficacy (SDMA)
            tvimax ∈ RealDomain(lower = 0.0001, init = 0.9, upper = 1)
            tvic50 ∈ RealDomain(lower = 0.0001, init = 2)
            tvkout ∈ RealDomain(lower = 0.0001, init = 0.03)
            tvsdma0 ∈ RealDomain(lower = 0.0001, init = 120)

            ωsdma0 ∈ RealDomain(lower = 0, init = 0.2)
            σ²sdma ∈ RealDomain(lower=0.0001, init = 0.1)
        end

        @random begin
            ηsdma0 ~ Normal(0, ωsdma0)
        end

        @covariates tdd freqn cli vci qi vpi kai fsi

        @pre begin
            # PK
            cl = cli
            vc = vci
            q = qi
            vp = vpi
            ka = kai

            # Drug effect on SDMA
            imax = tvimax
            ic50 = tvic50
            kout = tvkout
            sdma0 = tvsdma0*exp(ηsdma0)
            kin = sdma0*kout
        end

        @dosecontrol begin
            # F is both time- and dose-dependent
            fs = fsi
            bioav = (; depot = fs)
        end

        @init begin
            defsdma = sdma0
        end

        @dynamics begin
            # PK
            depot' = -ka*depot
            central' =  ka*depot - (cl+q)/vc*central + q/vp*peripheral
            peripheral' = q/vc*central - q/vp*peripheral
            
            # Drug-effect on SDMA (defsdma) 
            defsdma' = kin*(1 - imax*(central/vc) / (ic50 + (central/vc))) - kout*defsdma
        end

        @derived begin
            # (ng/mL)
            sdma ~ @. LogNormal(log(defsdma), sqrt(σ²sdma))
        end

    end
    ,
    params1 = (
        tvimax = 0.9,
        tvic50 = 2,
        tvkout = 0.03,
        tvsdma0 = 120,
        ωsdma0 = 0.2,
        σ²sdma = 0.1
    )
)