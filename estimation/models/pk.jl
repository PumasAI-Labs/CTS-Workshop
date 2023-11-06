##################################################################
# Initial estimates
##################################################################
#=
PK (PF-06939999) ----------------------
Fixed Effects   θ       Estimate    Units
tvcl            1       9.53        L/hr
tvvc            2       160         L
tvq             3       26.2        L/hr
tvvp            4       285         L
tvka            5       2.31        hr⁻¹
tvfs            6       0.647

Random Effects  CV%     VAR
IIV-CL          38.9    0.151
IIV-Vc          61.1    0.373
IIV-Q
IIV-Vp
IIV-ka
IIV-FS          53.6    0.287
RUV (exp)               0.112
=#

(; 
    mdl = @model begin

        @param begin
            # PK
            tvcl ∈ RealDomain(lower = 0.0001, init = 9.5)
            tvvc ∈ RealDomain(lower = 0.0001, init = 135)
            tvq ∈ RealDomain(lower = 0.0001, init = 26)
            tvvp ∈ RealDomain(lower = 0.0001, init = 235)
            tvka ∈ RealDomain(lower = 0.0001, init = 2)
            tvfs ∈ RealDomain(lower = 0.0001, init = 0.5)

            Ω ∈ PDiagDomain(3)
            σ²pk ∈ RealDomain(lower=0.0001, init = 0.1)
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
        end

        @dosecontrol begin
            # F is both time- and dose-dependent 
            f = t ≤ 24 && tdd ≤ 6 ? logistic(logit(tvfs) + η[3]) : 1
            bioav = (; depot = f)
        end

        @dynamics begin
            # PK
            depot' = -ka*depot
            central' =  ka*depot - (cl+q)/vc*central + q/vp*peripheral
            peripheral' = q/vc*central - q/vp*peripheral
        end

        @derived begin
            # PK (ng/mL)
            cp := @. central/vc
            dv ~ @. LogNormal(log(cp), sqrt(σ²pk))
        end

    end
)