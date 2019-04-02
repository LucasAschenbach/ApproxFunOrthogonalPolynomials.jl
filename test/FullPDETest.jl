using ApproxFun, LinearAlgebra, Test
import ApproxFun: resizedata!, CachedOperator, RaggedMatrix, testbandedblockbandedoperator,
                    testblockbandedoperator, ldiv_coefficients, mul_coefficients,
                    factor

@testset "Full PDE" begin
    @testset "Gaussian zero Dirichlet Poisson" begin
        S=JacobiWeight(1.,1.,Jacobi(1.,1.))^2
        Δ=Laplacian(S)

        f=Fun((x,y)->exp(-10(x+.2)^2-20(y-.1)^2),rangespace(Δ))  #default is [-1,1]^2
        @time v = \(Δ,f;tolerance=1E-14)
        @test norm((Δ*v-f).coefficients) < 1E-14

    end

    @testset "Neumann" begin
        d=ChebyshevInterval()^2

        @time u=\([Neumann(d); Laplacian(d)-100.0I],[[[1,1],[1,1]],0.];tolerance=1E-12)
        @test u(.1,.9) ≈ 0.03679861429138079
    end

    @testset "Transport" begin
        dx=ChebyshevInterval(); dt=Interval(0,2.)
        d=dx × dt
        Dx=Derivative(d,[1,0]);Dt=Derivative(d,[0,1])
        x,y=Fun(identity,d)
        @time u=\([I⊗ldirichlet(dt);Dt+x*Dx],[Fun(x->exp(-20x^2),dx);0.];tolerance=1E-12)

        @test u(0.1,0.2) ≈ 0.8745340845783758  # empirical
    end

    @testset "Bilaplacian" begin
        dx=dy=ChebyshevInterval()
        d=dx × dy
        Dx=Derivative(dx);Dy=Derivative(dy)
        L=Dx^4⊗I+2*Dx^2⊗Dy^2+I⊗Dy^4

        testbandedblockbandedoperator(L)

        A=[ldirichlet(dx)⊗Operator(I,dy);
                rdirichlet(dx)⊗Operator(I,dy);
                Operator(I,dx)⊗ldirichlet(dy);
                Operator(I,dx)⊗rdirichlet(dy);
                lneumann(dx)⊗Operator(I,dy);
                rneumann(dx)⊗Operator(I,dy);
                Operator(I,dx)⊗lneumann(dy);
                Operator(I,dx)⊗rneumann(dy);
                 L]


        # Checks bug in constructor
        f=Fun((x,y)->real(exp(x+1.0im*y)),component(rangespace(A)[1],1),22)
        @test f(-1.,0.1) ≈ real(exp(-1+0.1im))
        f=Fun((x,y)->real(exp(x+1.0im*y)),component(rangespace(A)[1],1))
        @test f(-1.,0.1) ≈ real(exp(-1+0.1im))


        F=[Fun((x,y)->real(exp(x+1.0im*y)),rangespace(A)[1]);
            Fun((x,y)->real(exp(x+1.0im*y)),rangespace(A)[2]);
            Fun((x,y)->real(exp(x+1.0im*y)),rangespace(A)[3]);
            Fun((x,y)->real(exp(x+1.0im*y)),rangespace(A)[4]);
            Fun((x,y)->real(exp(x+1.0im*y)),rangespace(A)[5]);
            Fun((x,y)->real(exp(x+1.0im*y)),rangespace(A)[6]);
            Fun((x,y)->-imag(exp(x+1.0im*y)),rangespace(A)[7]);
            Fun((x,y)->-imag(exp(x+1.0im*y)),rangespace(A)[8]);
            0]

        @time u=\(A,F;tolerance=1E-10)

        @test u(0.1,0.2)  ≈ exp(0.1)*cos(0.2)

        dx=dy=ChebyshevInterval()
        d=dx×dy
        Dx=Derivative(dx);Dy=Derivative(dy)
        L=Dx^4⊗I+2*Dx^2⊗Dy^2+I⊗Dy^4


        A=[(ldirichlet(dx)+lneumann(dx))⊗Operator(I,dy);
                (rdirichlet(dx)+rneumann(dx))⊗Operator(I,dy);
                Operator(I,dx)⊗(ldirichlet(dy)+lneumann(dy));
                Operator(I,dx)⊗(rdirichlet(dy)+rneumann(dy));
                (ldirichlet(dx)-lneumann(dx))⊗Operator(I,dy);
                (rdirichlet(dx)-rneumann(dx))⊗Operator(I,dy);
                Operator(I,dx)⊗(ldirichlet(dy)-lneumann(dy));
                Operator(I,dx)⊗(rdirichlet(dy)-rneumann(dy));
                 L]


        u=\(A,[fill(1.0,8);0];tolerance=1E-5)
        @test u(0.1,0.2) ≈ 1.0

        F=[2Fun((x,y)->real(exp(x+1.0im*y)),rangespace(A)[1]);
            2Fun((x,y)->real(exp(x+1.0im*y)),rangespace(A)[2]);
            Fun((x,y)->real(exp(x+1.0im*y))-imag(exp(x+1.0im*y)),rangespace(A)[3]);
            Fun((x,y)->real(exp(x+1.0im*y))-imag(exp(x+1.0im*y)),rangespace(A)[4]);
            0;
            0;
            Fun((x,y)->real(exp(x+1.0im*y))+imag(exp(x+1.0im*y)),rangespace(A)[7]);
            Fun((x,y)->real(exp(x+1.0im*y))+imag(exp(x+1.0im*y)),rangespace(A)[8]);
            0]

        u=\(A,F;tolerance=1E-10)

        @test u(0.1,0.2)  ≈ exp(0.1)*cos(0.2)
    end

    @testset "Operator resize" begin
        S=ChebyshevDirichlet()^2
        B=Dirichlet(S)
        f = Fun((x,y)->exp(x)*sin(y),S)
        @test norm((Fun((x,y)->exp(x)*sin(y),∂(domain(S))) - B*f).coefficients) < 100eps()


        S=JacobiWeight(1.,1.,Jacobi(1.,1.))^2
        Δ=Laplacian(S)

        @test cache(Δ)[1:100,1:100]  ≈ Δ[1:100,1:100]
        @test cache(Δ;padding=true)[1:100,1:100]  ≈ Δ[1:100,1:100]

        @test cache(Δ)[5:100,7:100]  ≈ Δ[5:100,7:100]
        @test cache(Δ;padding=true)[5:100,7:100]  ≈ Δ[5:100,7:100]

        # Check that QR is growing correctly
        for col in (1,2,3,10,11,40)
            QR=qr(Δ)
            resizedata!(QR.R_cache,:,col+100)
            resizedata!(QR,:,col)
            QR2=qr!(CachedOperator(RaggedMatrix,Δ;padding=true))
            resizedata!(QR2.R_cache,:,QR.ncols+100)
            resizedata!(QR2,:,QR.ncols)
            n=min(size(QR.H,1),size(QR2.H,1))
            @test QR.H[1:n,1:col] ≈ QR2.H[1:n,1:col]
            @test QR.R_cache[1:col,1:col] ≈ QR2.R_cache[1:col,1:col]
            @test QR.R_cache[1:col+10,1:col+10] ≈ QR2.R_cache[1:col+10,1:col+10]
        end

        QRR=qr(Δ)
        QR2=qr!(CachedOperator(RaggedMatrix,Δ;padding=true))
        for col in (80,200)
            resizedata!(QRR,:,col)
            resizedata!(QR2,:,QRR.ncols)
            n=min(size(QRR.H,1),size(QR2.H,1))
            @test QRR.H[1:n,1:col] ≈ QR2.H[1:n,1:col]
            @test QRR.R_cache[1:col,1:col] ≈ QR2.R_cache[1:col,1:col]
            @test QRR.R_cache[1:col+10,1:col+10] ≈ QR2.R_cache[1:col+10,1:col+10]
        end

        # this checks a bug
        QRR=qr(Δ)
        resizedata!(QRR,:,548)
        resizedata!(QRR,:,430)


        u=Fun((x,y)->sin(π*x)*sin(π*y),S)
        f=-2π^2*u


        QRR=qr(Δ)
        v=QRR\f
        @test norm((u-v).coefficients)<100eps()

        v=Δ\f
        @test norm((u-v).coefficients)<100eps()


        f=Fun((x,y)->exp(-10(x+.2)^2-20(y-.1)^2),rangespace(Δ))  #default is [-1,1]^2
        @time v=\(Δ,f;tolerance=1E-14)
        @test norm((Δ*v-f).coefficients)<1E-14

        KO=Δ.op.ops[1].ops[1].op

        M=ApproxFun.BandedBlockBandedMatrix(view(KO,1:4,1:4))
        @test norm(ApproxFun.BandedBlockBandedMatrix(view(KO,1:4,2:4))-M[:,2:4]) < 10eps()
        @test norm(ApproxFun.BandedBlockBandedMatrix(view(KO,1:4,3:4))-M[:,3:4]) < 10eps()
    end


    @testset "Check resizing" begin
        d=ChebyshevInterval()^2
        A=[Dirichlet(d);Laplacian()+100I]
        QRR = qr(A)
        @time ApproxFun.resizedata!(QRR.R_cache,:,2000)
        @test norm(QRR.R_cache.data[1:200,1:200] - A[1:200,1:200]) ==0

        @time ApproxFun.resizedata!(QRR,:,200)
        j=56
        v=QRR.R_cache.op[1:100,j]
        @test norm(ldiv_coefficients(QRR.Q,v;maxlength=300)[j+1:end]) < 100eps()

        j=195
        v=QRR.R_cache.op[1:ApproxFun.colstop(QRR.R_cache.op,j),j]
        @test norm(ldiv_coefficients(QRR.Q,v;maxlength=1000)[j+1:end]) < 100eps()


        j=300
        v=QRR.R_cache.op[1:ApproxFun.colstop(QRR.R_cache.op,j),j]
        @test norm(ldiv_coefficients(QRR.Q,v;maxlength=1000)[j+1:end]) < j*20eps()

        @test ApproxFun.colstop(QRR.R_cache.op,195)-194 == ApproxFun.colstop(QRR.H,195)


        QR1 = qr(A)
        @time ApproxFun.resizedata!(QR1.R_cache,:,1000)
        QR2 = qr([Dirichlet(d);Laplacian()+100I])
        @time ApproxFun.resizedata!(QR2.R_cache,:,500)
        n=450;QR1.R_cache.data[1:n,1:n]-QR2.R_cache.data[1:n,1:n]|>norm
        @time ApproxFun.resizedata!(QR2.R_cache,:,1000)
        N=450;QR1.R_cache.data[1:N,1:N]-QR2.R_cache.data[1:N,1:N]|>norm
        N=1000;QR1.R_cache.data[1:N,1:N]-QR2.R_cache.data[1:N,1:N]|>norm

        QR1 = qr(A)
        @time ApproxFun.resizedata!(QR1,:,1000)
        QR2 = qr([Dirichlet(d);Laplacian()+100I])
        @time ApproxFun.resizedata!(QR2,:,500)
        @time ApproxFun.resizedata!(QR2,:,1000)

        @test norm(QR1.H[1:225,1:1000]-QR2.H[1:225,1:1000]) ≤ 10eps()

        QR1 = qr(A)
        @time ApproxFun.resizedata!(QR1,:,5000)
        @time u=\(QR1,[ones(∂(d));0.];tolerance=1E-7)

        @test norm((Dirichlet(d)*u-ones(∂(d))).coefficients) < 1E-7
        @test norm((A*u-Fun([ones(∂(d));0.])).coefficients) < 1E-7
        @test norm(((A*u)[2]-(Laplacian(space(u))+100I)*u).coefficients) < 1E-10
        @test eltype(ApproxFun.promotedomainspace(Laplacian(),space(u))) == Float64
        @test eltype(ApproxFun.promotedomainspace(Laplacian()+100I,space(u))) == Float64
        @test norm(((A*u)[2]-(Laplacian()+100I)*u).coefficients) < 1E-10
        @test norm((Laplacian()*u+100*u - (A*u)[2]).coefficients) < 10E-10
        @time v=\(A,[ones(∂(d));0.];tolerance=1E-7)
        @test norm((u-v).coefficients) < 100eps()

        @test u(0.1,1.) ≈ 1.0
        @test u(0.1,-1.) ≈ 1.0
        @test u(1.,0.1) ≈ 1.0
        @test u(-1.,0.1) ≈ 1.0
    end

    @testset "Chebyshev Dirichlet Kronecker" begin
        S=ChebyshevDirichlet()^2
        ff=(x,y)->exp(x)*cos(y)
        u=Fun(ff,S)

        for KO in [Operator(I,factor(S,1))⊗rdirichlet(factor(S,1)),
                    rdirichlet(factor(S,1))⊗Operator(I,factor(S,2))]
            testblockbandedoperator(KO)
            @test norm((KO*u-Fun(ff,rangespace(KO))).coefficients) ≤ 1E-10
        end
    end

    @testset "Small diffusion" begin
        dx=ChebyshevInterval();dt=Interval(0,0.2)
        d=dx×dt
        Dx=Derivative(d,[1,0]);Dt=Derivative(d,[0,1])
        x,t=Fun(dx×dt)

        B=0.0
        C=0.0
        V=B+C*x
        ε=0.1
        f=Fun(x->exp(-30x^2),dx)
        u=\([timedirichlet(d);Dt-ε*Dx^2-V*Dx],[f;zeros(3)];tolerance=1E-6)

        @test u(.1,.2) ≈ 0.496524222625512
        B=0.1
        C=0.2
        V=B+C*x
        u=\([timedirichlet(d);Dt-ε*Dx^2-V*Dx],[f;zeros(3)];tolerance=1E-7)
        @test u(.1,.2) ≈ 0.46810331039791464
    end

    @testset "concatenate InterlaceOperator" begin
        a=Fun(x -> 0 ≤ x ≤ 0.5 ? 0.5 : 1, Domain(-1..1) \ [0,0.5])
        @test a(0.1) == 0.5
        @test a(0.7) == 1.0
        s=space(a)
        # Bx=[ldirichlet(s);continuity(s,0)]
        # TODO: this should concat
        dt=Interval(0,2.)
        Dx=Derivative(s);Dt=Derivative(dt)
        Bx=[ldirichlet(s);continuity(s,0)]

        @test ApproxFun.rangetype(rangespace(continuity(s,0))) == Vector{Float64}
        @test ApproxFun.rangetype(rangespace(Bx)) == Vector{Any}
        @test ApproxFun.rangetype(rangespace(Bx⊗Operator(I,Chebyshev()))) == Vector{Any}

        rhs = Fun([0,[0,[0,0]],0],rangespace([I⊗ldirichlet(dt);Bx⊗I;I⊗Dt+(a*Dx)⊗I]))
        @test rhs(-0.5,0.0) == [0,[0,[0,0]],0]


        u=\([I⊗ldirichlet(dt);Bx⊗I;I⊗Dt+(a*Dx)⊗I],
            [Fun(x->exp(-20(x+0.5)^2),s),[[0],[0,0]],0.0];tolerance=1E-2)

        @test u(-0.4,0.1) ≈ u(-0.5,0.0) atol = 0.0001
    end
end
