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
            # PK
            cp := @. central/vc
            dv ~ @. LogNormal(log(cp), sqrt(σ²pk))
        end

    end
)