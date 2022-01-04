function Init_cold_4D(NX,NY,NZ,NT,Nwing,NC)
    Dim = 4

    u1 = IdentityGauges(NC,Nwing,NX,NY,NZ,NT)
    U = Array{typeof(u1),1}(undef,Dim)
    U[1] = u1
    for μ=2:Dim
        U[μ] = IdentityGauges(NC,Nwing,NX,NY,NZ,NT)
    end
    

    temp1 = similar(U[1])
    temp2 = similar(U[1])

    comb = 6
    factor = 1/(comb*U[1].NV*U[1].NC)

    #factor = 2/(U[1].NV*4*3*U[1].NC)
    @time plaq_t = calculate_Plaquette(U,temp1,temp2)*factor
    println("plaq_t = $plaq_t")
    poly = calculate_Polyakov_loop(U,temp1,temp2) 
    println("polyakov loop = $(real(poly)) $(imag(poly))")
    return plaq_t
    

end

function Init_hot_4D(NX,NY,NZ,NT,Nwing,NC)
    Random.seed!(123)
    Dim = 4

    u1 = RandomGauges(NC,Nwing,NX,NY,NZ,NT)
    U = Array{typeof(u1),1}(undef,Dim)
    U[1] = u1
    for μ=2:Dim
        U[μ] = RandomGauges(NC,Nwing,NX,NY,NZ,NT)
    end
    

    temp1 = similar(U[1])
    temp2 = similar(U[1])

    comb = 6
    factor = 1/(comb*U[1].NV*U[1].NC)

    #factor = 2/(U[1].NV*4*3*U[1].NC)
    @time plaq_t = calculate_Plaquette(U,temp1,temp2)*factor
    println("plaq_t = $plaq_t")
    poly = calculate_Polyakov_loop(U,temp1,temp2) 
    println("polyakov loop = $(real(poly)) $(imag(poly))")
    return plaq_t

end

function Init_ildg_4D(NX,NY,NZ,NT,Nwing,NC,filename)
    Dim = 4
    u1 = IdentityGauges(NC,Nwing,NX,NY,NZ,NT)
    U = Array{typeof(u1),1}(undef,Dim)

    ildg = ILDG(filename)
    i = 1
    for μ=1:Dim
        U[μ] = IdentityGauges(NC,Nwing,NX,NY,NZ,NT)
        #U[μ] = IdentityGauges(NC,NX,NY,NZ,NT,Nwing)
    end
    L = [NX,NY,NZ,NT]
    load_gaugefield!(U,i,ildg,L,NC)

    temp1 = similar(U[1])
    temp2 = similar(U[1])

    comb = 6
    factor = 1/(comb*U[1].NV*U[1].NC)
    @time plaq_t = calculate_Plaquette(U,temp1,temp2)*factor
    poly = calculate_Polyakov_loop(U,temp1,temp2) 
    println("polyakov loop = $(real(poly)) $(imag(poly))")
    return plaq_t

end

function Init_cold_2D(NX,NT,Nwing,NC)
    Dim = 2

    u1 = IdentityGauges(NC,Nwing,NX,NT)
    U = Array{typeof(u1),1}(undef,Dim)
    U[1] = u1
    for μ=2:Dim
        U[μ] = IdentityGauges(NC,Nwing,NX,NT)
    end
    

    temp1 = similar(U[1])
    temp2 = similar(U[1])

    if Dim == 4
        comb = 6 #4*3/2
    elseif Dim == 3
        comb = 3
    elseif Dim == 2
        comb = 1
    else
        error("dimension $Dim is not supported")
    end
    factor = 1/(comb*U[1].NV*U[1].NC)

    #factor = 2/(U[1].NV*4*3*U[1].NC)
    @time plaq_t = calculate_Plaquette(U,temp1,temp2)*factor
    println("plaq_t = $plaq_t")
    poly = calculate_Polyakov_loop(U,temp1,temp2) 
    println("polyakov loop = $(real(poly)) $(imag(poly))")
    return plaq_t
    

end

function Init_hot_2D(NX,NT,Nwing,NC)
    Random.seed!(123)
    Dim = 2

    u1 = RandomGauges(NC,Nwing,NX,NT)
    U = Array{typeof(u1),1}(undef,Dim)
    U[1] = u1
    for μ=2:Dim
        U[μ] = RandomGauges(NC,Nwing,NX,NT)
    end
    

    temp1 = similar(U[1])
    temp2 = similar(U[1])

    if Dim == 4
        comb = 6 #4*3/2
    elseif Dim == 3
        comb = 3
    elseif Dim == 2
        comb = 1
    else
        error("dimension $Dim is not supported")
    end
    factor = 1/(comb*U[1].NV*U[1].NC)

    #factor = 2/(U[1].NV*4*3*U[1].NC)
    @time plaq_t = calculate_Plaquette(U,temp1,temp2)*factor
    println("plaq_t = $plaq_t")
    poly = calculate_Polyakov_loop(U,temp1,temp2) 
    println("polyakov loop = $(real(poly)) $(imag(poly))")
    return plaq_t

end


@testset "cold start" begin
    println("cold start")
    println("4D system")
    @testset "4D" begin
        NX = 4
        NY = 4
        NZ = 4
        NT = 4
        Nwing = 1
        
        @testset "NC=2" begin
            NC = 2
            println("NC = $NC")
            plaq_t = Init_cold_4D(NX,NY,NZ,NT,Nwing,NC)

            @test plaq_t == one(plaq_t)
        end

        @testset "NC=3" begin
            NC = 3
            println("NC = $NC")
            plaq_t = Init_cold_4D(NX,NY,NZ,NT,Nwing,NC)
            @test plaq_t == one(plaq_t)
        end

        @testset "NC=4" begin
            NC = 4
            println("NC = $NC")
            plaq_t = Init_cold_4D(NX,NY,NZ,NT,Nwing,NC)
            @test plaq_t == one(plaq_t)
        end

        @testset "NC=5" begin
            NC = 5
            println("NC = $NC")
            plaq_t = Init_cold_4D(NX,NY,NZ,NT,Nwing,NC)
            @test plaq_t == one(plaq_t)
        end
    end

    println("2D system")
    @testset "2D" begin
        NX = 4
        #NY = 4
        #NZ = 4
        NT = 4
        Nwing = 1
        
        @testset "NC=2" begin
            NC = 2
            println("NC = $NC")
            plaq_t = Init_cold_2D(NX,NT,Nwing,NC)

            @test plaq_t == one(plaq_t)
        end

        @testset "NC=3" begin
            NC = 3
            println("NC = $NC")
            plaq_t = Init_cold_2D(NX,NT,Nwing,NC)
            @test plaq_t == one(plaq_t)
        end

        @testset "NC=4" begin
            NC = 4
            println("NC = $NC")
            plaq_t = Init_cold_2D(NX,NT,Nwing,NC)
            @test plaq_t == one(plaq_t)
        end

        @testset "NC=5" begin
            NC = 5
            println("NC = $NC")
            plaq_t = Init_cold_2D(NX,NT,Nwing,NC)
            @test plaq_t == one(plaq_t)
        end
    end
end

eps = 1e-8

@testset "hot start" begin
    println("hot start")
    println("4D system")
    @testset "4D" begin
        NX = 4
        NY = 4
        NZ = 4
        NT = 4
        Nwing = 1

        @testset "NC=2" begin
            NC = 2
            println("NC = $NC")
            plaq_t = Init_hot_4D(NX,NY,NZ,NT,Nwing,NC)
            val = -0.007853743153861802
            @test abs(plaq_t-val)/abs(val) < eps
        end

        @testset "NC=3" begin
            NC = 3
            println("NC = $NC")
            plaq_t = Init_hot_4D(NX,NY,NZ,NT,Nwing,NC)
            val = 0.0015014233929744197
            @test abs(plaq_t-val)/abs(val) < eps
        end

        @testset "NC=4" begin
            NC = 4
            println("NC = $NC")
            plaq_t = Init_hot_4D(NX,NY,NZ,NT,Nwing,NC)
            val = -0.004597227507817238
            @test abs(plaq_t-val)/abs(val) < eps
        end

        @testset "NC=5" begin
            NC = 5
            println("NC = $NC")
            plaq_t = Init_hot_4D(NX,NY,NZ,NT,Nwing,NC)
            val = 0.0037580826460029506
            @test abs(plaq_t-val)/abs(val) < eps
        end
    end

    println("2D system")
    @testset "2D" begin
        NX = 4
        #NY = 4
        #NZ = 4
        NT = 4
        Nwing = 1

        @testset "NC=2" begin
            NC = 2
            println("NC = $NC")
            plaq_t = Init_hot_2D(NX,NT,Nwing,NC)
            val = 0.022601163616639157
            @test abs(plaq_t-val)/abs(val) < eps
        end

        @testset "NC=3" begin
            NC = 3
            println("NC = $NC")
            plaq_t = Init_hot_2D(NX,NT,Nwing,NC)
            val = -0.04647124293538649
            @test abs(plaq_t-val)/abs(val) < eps
        end

        @testset "NC=4" begin
            NC = 4
            println("NC = $NC")
            plaq_t = Init_hot_2D(NX,NT,Nwing,NC)
            val = 0.07457370324173362
            @test abs(plaq_t-val)/abs(val) < eps
        end

        @testset "NC=5" begin
            NC = 5
            println("NC = $NC")
            plaq_t = Init_hot_2D(NX,NT,Nwing,NC)
            val = -0.013511504030861661
            @test abs(plaq_t-val)/abs(val) < eps
        end
    end

end

@testset "one instanton" begin
    @testset "4D" begin
        NX = 4
        NY = 4
        NZ = 4
        NT = 4
        NC = 2
        Nwing = 1
        U = Oneinstanton(NC,NX,NY,NZ,NT,Nwing)

        comb = 6
        factor = 1/(comb*U[1].NV*U[1].NC)

        temp1 = similar(U[1])
        temp2 = similar(U[1])

        @time plaq_t = calculate_Plaquette(U,temp1,temp2)*factor
        println("plaq_t = $plaq_t")
        val =  0.9796864531099871
        @test abs(plaq_t-val)/abs(val) < eps
    end

    @testset "2D" begin
        Dim = 2
        NX = 4
        #NY = 4
        #NZ = 4
        NT = 4
        NC = 2
        Nwing = 1
        U = Oneinstanton(NC,NX,NT,Nwing)

        if Dim == 4
            comb = 6 #4*3/2
        elseif Dim == 3
            comb = 3
        elseif Dim == 2
            comb = 1
        else
            error("dimension $Dim is not supported")
        end
        factor = 1/(comb*U[1].NV*U[1].NC)

        temp1 = similar(U[1])
        temp2 = similar(U[1])

        @time plaq_t = calculate_Plaquette(U,temp1,temp2)*factor
        println("plaq_t = $plaq_t")
        val = 0.9300052284270868
        @test abs(plaq_t-val)/abs(val) < eps
    end
end

@testset "File start" begin
    @testset "4444 SU(2)" begin
        Dim = 4
        NX = 4
        NY = 4
        NZ = 4
        NT = 4
        NC = 2
        Nwing = 1
        filename = "./data/conf_00000100_4444nc2.ildg"
        plaq_t = Init_ildg_4D(NX,NY,NZ,NT,Nwing,NC,filename)
        
        println("plaq_t = $plaq_t")
        val = 0.6684748868359871
        @test abs(plaq_t-val)/abs(val) < eps
    end
end