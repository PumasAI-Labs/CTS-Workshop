##################################################################
# PK (PF-06) Initial Estimates
##################################################################
#=
Fixed Effects   θ       Estimate    Units
tvcl            1       9.5         L/hr
tvvc            2       135         L
tvq             3       26          L/hr
tvvp            4       235         L
tvka            5       2.0         hr⁻¹
tvfs            6       0.5

Random Effects  CV%     VAR
IIV-CL          20%     -
IIV-Vc          20%     -
IIV-FS          20%     -
RUV (exp)               0.1
=#
(; 
    mdl = @model begin

        @param begin
            tvcl ∈ RealDomain(lower = 0.0001, init = 9.5)
            tvvc ∈ RealDomain(lower = 0.0001, init = 135)
            tvq ∈ RealDomain(lower = 0.0001, init = 26)
            tvvp ∈ RealDomain(lower = 0.0001, init = 235)
            tvka ∈ RealDomain(lower = 0.0001, init = 2)
            tvfs ∈ RealDomain(lower = 0.0001, init = 0.5) #* scaling factor on relative bioav

            ωcl ∈ RealDomain(lower = 0, init = 0.2)
            ωvc ∈ RealDomain(lower = 0, init = 0.2)
            ωfs ∈ RealDomain(lower = 0, init = 0.2)
            σ²pk ∈ RealDomain(lower=0.0001, init = 0.1)
        end

        @random begin
            ηcl ~ Normal(0, ωcl)
            ηvc ~ Normal(0, ωvc)
            ηfs ~ Normal(0, ωfs)
        end

        @covariates tdd freqn

        @pre begin
            cl = tvcl * exp(ηcl)
            vc = tvvc * exp(ηvc)
            q = tvq
            vp = tvvp
            ka = tvka
        end

        @dosecontrol begin
            # FS is both time- and dose-dependent 
            fs = t ≤ 24 && tdd ≤ 6 ? logistic(logit(tvfs) + ηfs) : 1
            bioav = (; depot = fs)
        end

        @dynamics begin
            # PK
            depot' = -ka*depot
            central' =  ka*depot - (cl+q)/vc*central + q/vp*peripheral
            peripheral' = q/vc*central - q/vp*peripheral
        end

        @derived begin
            # PK (ng/mL)
            #* use the walrus operator (:=) to exclude cp from output, or (=) to include
            cp := @. central/vc
            dv ~ @. LogNormal(log(cp), sqrt(σ²pk))
        end

    end
    ,
    params1 = (
        tvcl = 9.5,
        tvvc = 135,
        tvq = 26,
        tvvp = 235,
        tvka = 2,
        tvfs = 0.5,
        ωcl = 0.2,
        ωvc = 0.2,
        ωfs = 0.2,
        σ²pk = 0.1
    )
)