##################################################################
# Integrated Model
##################################################################
#=
PK (PF-06939999) ----------------------
Fixed Effects   θ       Estimate    Units
tvcl            1       10.7        L/hr
tvvc            2       170         L
tvq             3       27.2        L/hr
tvvp            4       301         L
tvka            5       2.37        hr⁻¹
tvfs            6       0.73

Random Effects  CV%     VAR         SD
IIV-CL          28.4    -           0.284
IIV-Vc          61.4    -           0.614
IIV-Q           -       -
IIV-Vp          -       -
IIV-ka          -       -
IIV-FS          73.3    -           0.733
RUV (exp)       -       0.103

PD-Efficacy (SDMA) --------------------
Fixed Effects   θ       Estimate
tvimax          1       0.820   
tvic50          2       0.392       ng/mL = μg/L
tvkout          3       0.00687     hr⁻¹
sdma0           4       124         ng/mL = μg/L

Random Effects  CV%     VAR         SD
IIV-Imax        -       -
IIV-IC50        -       -
IIV-Kout        -       -
IIV-SDMA0       25.2    -            0.252
RUV (add)       -       0.0155


PD-Safety (Platelets)  ----------------
Fixed Effects   θ       Estimate    Units
tvmtt           1       138         hr
tvslope         2       0.00586
tvγ             3       0.223
tvplt0          4       243         10⁹/L

Random Effects  CV%     VAR         SD
IIV-MTT         -       -           -
IIV-Slope       39      -           0.39
IIV-Gamma       35.3    -           0.354
IIV-PLT0        27.6    -           0.276
RUV (exp)       -       0.0236
=#

(; 

    mdl = @model begin

        @metadata begin
            desc = "Final Combined Indirect PK (PF06) and PD (SDMA, PLT) Model"
            timeu = u"hr"
            tag = "combined_pkpd"
        end

        @param begin
            # PK
            tvcl ∈ RealDomain(init = 10.7)
            tvvc ∈ RealDomain(init = 170)
            tvq ∈ RealDomain(init = 27.2)
            tvvp ∈ RealDomain(init = 301)
            tvka ∈ RealDomain(init = 2.37)
            tvfs ∈ RealDomain(init = 0.73)

            # Efficacy (SDMA)
            tvimax ∈ RealDomain(init = 0.82)
            tvic50 ∈ RealDomain(init = 0.392)
            tvsdma0 ∈ RealDomain(init = 124)
            tvkout ∈ RealDomain(init = 0.00687)
            
            # Safety (Platelets)
            tvmtt ∈ RealDomain(init = 138)
            tvslope ∈ RealDomain(init = 0.00586)
            tvγ ∈ RealDomain(init = 0.223)
            tvcirc0 ∈ RealDomain(init = 243)

            # IIV
            ωcl ∈ RealDomain(init = 0.284)
            ωvc ∈ RealDomain(init = 0.614)
            ωfs ∈ RealDomain(init = 0.733)
            ωsdma0 ∈ RealDomain(init = 0.252)
            ωslope ∈ RealDomain(init = 0.39)
            ωγ ∈ RealDomain(init = 0.354)
            ωcirc0 ∈ RealDomain(init = 0.276)
            
            # RUV
            σ²pk ∈ RealDomain(init = 0.103)
            σ²sdma ∈ RealDomain(init = 0.0155)
            σ²plt ∈ RealDomain(init = 0.0236)
        end

        @random begin
            # PK
            ηcl ~ Normal(0, ωcl)
            ηvc ~ Normal(0, ωvc)
            ηfs ~ Normal(0, ωfs)
            # SDMA
            ηsdma0 ~ Normal(0, ωsdma0)
            # PLT
            ηslope ~ Normal(0, ωslope)
            ηγ ~ Normal(0, ωγ)
            ηcirc0 ~ Normal(0, ωcirc0)
        end

        @covariates tdd freqn

        @pre begin
            # PK
            cl = tvcl * exp(ηcl)
            vc = tvvc * exp(ηvc)
            q = tvq
            vp = tvvp
            ka = tvka

            # Efficacy
            imax = tvimax
            ic50 = tvic50
            sdma0 = tvsdma0 * exp(ηsdma0)
            kout = tvkout
            kin = sdma0*kout

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
            fs = t ≤ 24 && tdd ≤ 6 ? logistic(logit(tvfs) + ηfs) : 1
            bioav = (; depot = fs)
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
            # PK (ng/mL)
            cp := @. central/vc
            dv ~ @. LogNormal(log(cp), sqrt(σ²pk))
            # SDMA (ng/mL)
            sdma ~ @. LogNormal(log(defsdma), sqrt(σ²sdma))
            # Platelets (10⁹/L)
            plt ~ @. LogNormal(log(circ), sqrt(σ²plt))
        end

    end
)