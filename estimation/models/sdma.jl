##################################################################
# Initial estimates
##################################################################
#=
PD-Efficacy (SDMA) --------------------
Fixed Effects   θ       Estimate    Units
tvimax          1       0.823   
tvic50          2       0.425       ng/mL = μg/L
tvkout          3       0.00708     hr⁻¹
sdma0           4       113         ng/mL = μg/L

Random Effects  CV%     VAR
IIV-Imax        -
IIV-IC50        -
IIV-Kout        -               
IIV-SDMA0       29.1    0.084
RUV (add)       -       0.0146

Correlation     r       cov [cov = r * sqrt(var1*var2)] #* included for reference, not in model
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

            Ω ∈ PDiagDomain(1)
            σ²sdma ∈ RealDomain(lower=0.0001, init = 0.1)
        end

        @random begin
            η ~ MvNormal(Ω)
        end

        @covariates tdd freqn cli vci qi vpi kai fi

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
            sdma0 = tvsdma0*exp(η[1])
            kin = sdma0*kout
        end

        @dosecontrol begin
            # F is both time- and dose-dependent
            f = fi
            bioav = (; depot = f)
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
            # SDMA
            sdma ~ @. LogNormal(log(defsdma), sqrt(σ²sdma))
        end

    end
)