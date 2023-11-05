#using Pumas: logit
##################################################################
# Integrated Model
##################################################################
#=
PK (PF-06939999) ----------------------
Fixed Effects   θ   Estimate
tvcl            1   9.53 L/hr
tvvc            2   160 L
tvq             3   26.2 L/hr
tvvp            4   285 L
tvka            5   2.31 hr^-1
tvfs            6   0.647

Random Effects  CV%     VAR
IIV-CL          38.9    0.151
IIV-Vc          61.1    0.373
IIV-Q
IIV-Vp
IIV-ka
IIV-FS          53.6    0.287
RUV (exp)               0.112

PD-Efficacy (SDMA) --------------------
Fixed Effects   θ   Estimate
tvimax          1   0.823   
tvic50          2   0.425 ng/mL = μg/L
tvkout          3   0.00708
sdma0           4   113 ng/mL = μg/L

Random Effects  CV%     VAR
IIV-Imax        -
IIV-IC50        -
IIV-Kout        -
IIV-SDMA0       29.1    0.084
RUV (add)       -       0.0146

Correlation     r       cov [cov = r * sqrt(var1*var2)] #* included for reference, not in model
CL-Vc                   0.01 

PD-Safety (Platelets)  ----------------
Fixed Effects   θ   Estimate
tvmtt           1   134 hr
tvslope         2   0.00496
tvgamma         3   0.217
tvplt0          4   232 10⁹/L

Random Effects  CV%     VAR
IIV-MTT         -
IIV-Slope       52.2    0.272
IIV-Gamma       46.9    0.22
IIV-PLT0        28.3    0.08
RUV (exp)               0.0235

Correlation     r       cov [cov = r * sqrt(var1*var2)] #* included for reference, not in model
Slope-Gamma             0.01 
Slope-PLT0              0.01
Gamma-PLT0              0.01
=#

(; 

    mdl = @model begin

        @metadata begin
            desc = "Combined Indirect PK/PD Model from Literature Reference"
            timeu = u"hr"
            tag = "combined_pkpd_ref"
        end

        @param begin
            # PK
            tvcl ∈ RealDomain(init = 9.53)
            tvvc ∈ RealDomain(init = 160)
            tvq ∈ RealDomain(init = 26.2)
            tvvp ∈ RealDomain(init = 285)
            tvka ∈ RealDomain(init = 2.31)
            tvfs ∈ RealDomain(init = 0.647)

            # Efficacy (SDMA)
            tvimax ∈ RealDomain(init = 0.823)
            tvic50 ∈ RealDomain(init = 0.425)
            tvsdma0 ∈ RealDomain(init = 113)
            tvkout ∈ RealDomain(init = 0.00708)
            
            # Safety (Platelets)
            tvmtt ∈ RealDomain(init = 134)
            tvslope ∈ RealDomain(init = 0.00496)
            tvgamma ∈ RealDomain(init = 0.217)
            tvcirc0 ∈ RealDomain(init = 232)

            Ω ∈ PDiagDomain(init = [0.151, 0.373, 0.287, 0.084, 0.272, 0.22, 0.08])
            σ²pk ∈ RealDomain(init = 0.112)
            σ²sdma ∈ RealDomain(init = 0.0146)
            σ²plt ∈ RealDomain(init = 0.0235)
        end

        @random begin
            η ~ MvNormal(Ω)
        end

        @covariates tdd freqn

        @pre begin
            # PK
            cl = tvcl * exp(η[1])
            vc = tvvc * exp(η[2])
            q = tvq
            vp = tvvp
            ka = tvka

            # Efficacy
            imax = tvimax
            ic50 = tvic50
            sdma0 = tvsdma0 * exp(η[4])
            kout = tvkout
            kin = sdma0*kout

            # Safety
            mtt = tvmtt
            ktr = 4/mtt
            kprol = ktr
            kcirc = ktr
            slope = tvslope * exp(η[5])
            γ = tvgamma * exp(η[6])
            circ0 = tvcirc0 * exp(η[7])
        end

        @dosecontrol begin
            # F is both time- and dose-dependent 
            f = t ≤ 24 && tdd ≤ 6 ? logistic(logit(tvfs) + η[3]) : 1
            bioav = (; depot = f)
        end

        @init begin
            defsdma = sdma0
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
            # Drug effect on SDMA (Imax)
            defsdma' = kin*(1 - (imax*(central/vc)/(ic50 + (central/vc)))) - kout*defsdma
            # Drug effect on Platelets (Friberg)
            prol' = kprol*prol * (1-(slope*central/vc)) * (circ0/(circ+1))^γ - ktr*prol
            tran1' = ktr*prol - ktr*tran1
            tran2' = ktr*tran1 - ktr*tran2
            tran3' = ktr*tran2 - ktr*tran3
            circ' = ktr*tran3 - kcirc*circ
        end

        @derived begin
            # PK
            cp := @. central/vc
            dv ~ @. LogNormal(log(cp), sqrt(σ²pk))
            # SDMA
            sdma ~ @. LogNormal(log(defsdma), sqrt(σ²sdma))
            # Platelets
            plt ~ @. LogNormal(log(circ), sqrt(σ²plt))
        end

    end
)