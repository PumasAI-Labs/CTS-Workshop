(; 
    mdl = @model begin

        @param begin        
            # Safety (Platelets)
            tvmtt ∈ RealDomain(lower = 0.0001, init = 100)
            tvslope ∈ RealDomain(lower = 0.0001, init = 0.003)
            tvgamma ∈ RealDomain(lower = 0.0001, init = 0.1)
            tvcirc0 ∈ RealDomain(lower = 0.0001, init = 200)

            Ω ∈ PDiagDomain(3)
            σ²plt ∈ RealDomain(lower=0.0001, init = 0.1)
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

            # Safety
            mtt = tvmtt
            ktr = 4/mtt
            kprol = ktr
            kcirc = ktr
            slope = tvslope * exp(η[1])
            γ = tvgamma * exp(η[2])
            circ0 = tvcirc0 * exp(η[3])
        end

        @dosecontrol begin
            # F is both time- and dose-dependent 
            f = fi
            bioav = (; depot = f)
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