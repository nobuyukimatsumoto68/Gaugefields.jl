#=
module Gaugefields_4D_mpi_module
    using LinearAlgebra
    import ..AbstractGaugefields_module:AbstractGaugefields,Shifted_Gaugefields,shift_U,
                        Adjoint_Gaugefields,set_wing_U!,Abstractfields,construct_staple!,clear_U!,
                        calculate_Plaquette
    import Base
    import ..Gaugefields_4D_module:Gaugefields_4D
    
    using MPI
    =#

    const comm = MPI.COMM_WORLD

    """
    `Gaugefields_4D_wing_mpi{NC} <: Gaugefields_4D{NC}`

    MPI version of SU(N) Gauge fields in four dimensional lattice. 
    """
    struct Gaugefields_4D_wing_mpi{NC} <: Gaugefields_4D{NC}
        U::Array{ComplexF64,6}
        NX::Int64
        NY::Int64
        NZ::Int64
        NT::Int64
        NDW::Int64
        NV::Int64
        NC::Int64
        PEs::NTuple{4,Int64}
        PN::NTuple{4,Int64}
        mpiinit::Bool
        myrank::Int64
        nprocs::Int64
        myrank_xyzt::NTuple{4,Int64}
        mpi::Bool
        verbose_print::Verbose_print

        function Gaugefields_4D_wing_mpi(NC::T,NDW::T,NX::T,NY::T,NZ::T,NT::T,PEs;mpiinit=true,
                                                            verbose_level = 2) where T<: Integer
            NV = NX*NY*NZ*NT
            @assert NX % PEs[1] == 0 "NX % PEs[1] should be 0. Now NX = $NX and PEs = $PEs"
            @assert NY % PEs[2] == 0 "NY % PEs[2] should be 0. Now NY = $NY and PEs = $PEs"
            @assert NZ % PEs[3] == 0 "NZ % PEs[3] should be 0. Now NZ = $NZ and PEs = $PEs"
            @assert NT % PEs[4] == 0 "NT % PEs[4] should be 0. Now NT = $NT and PEs = $PEs"

            PN = (NX ÷ PEs[1],
                    NY ÷ PEs[2],
                    NZ ÷ PEs[3],
                    NT ÷ PEs[4],
            )

            if mpiinit == false
                MPI.Init()
                mpiinit = true
            end

            comm = MPI.COMM_WORLD

            nprocs = MPI.Comm_size(comm)
            @assert prod(PEs) == nprocs "num. of MPI process should be prod(PEs). Now nprocs = $nprocs and PEs = $PEs"
            myrank = MPI.Comm_rank(comm)

            verbose_print = Verbose_print(verbose_level,myid = myrank)

            myrank_xyzt = get_myrank_xyzt(myrank,PEs)

            #println("Hello world, I am $(MPI.Comm_rank(comm)) of $(MPI.Comm_size(comm))")

            U = zeros(ComplexF64,NC,NC,PN[1]+2NDW,PN[2]+2NDW,PN[3]+2NDW,PN[4]+2NDW)
            #U = Array{Array{ComplexF64,6}}(undef,4)
            #for μ=1:4
            #    U[μ] = zeros(ComplexF64,NC,NC,NX+2NDW,NY+2NDW,NZ+2NDW,NT+2NDW)
            #end
            mpi = true
            return new{NC}(U,NX,NY,NZ,NT,NDW,NV,NC,Tuple(PEs),PN,mpiinit,myrank,nprocs,myrank_xyzt,mpi,verbose_print)
        end
    end

    function get_myrank_xyzt(myrank,PEs)
        #myrank = (((myrank_t)*PEs[3]+myrank_z)*PEs[2] + myrank_y)*PEs[1] + myrank_x
        myrank_x = myrank % PEs[1] 
        i = (myrank - myrank_x) ÷ PEs[1]
        myrank_y = i % PEs[2]
        i = (i - myrank_y) ÷ PEs[2]
        myrank_z = i % PEs[3]
        myrank_t = (i - myrank_z) ÷ PEs[3]

        return myrank_x,myrank_y,myrank_z,myrank_t
    end

    function get_myrank(myrank_xyzt,PEs)
        @inbounds return (((myrank_xyzt[4])*PEs[3]+myrank_xyzt[3])*PEs[2] + myrank_xyzt[2])*PEs[1] + myrank_xyzt[1]
    end

    function get_myrank(U::T) where T <: Gaugefields_4D_wing_mpi
        return U.myrank
    end

    function get_myrank(U::Array{T,1}) where T <: Gaugefields_4D_wing_mpi
        return U[1].myrank
    end

    function get_nprocs(U::T) where T <: Gaugefields_4D_wing_mpi
        return  U.nprocs
    end

    function get_nprocs(U::Array{T,1}) where T <: Gaugefields_4D_wing_mpi
        return U[1].nprocs
    end

    function calc_rank_and_indices(x::Gaugefields_4D_wing_mpi,ix,iy,iz,it)
        pex = (ix-1) ÷ x.PN[1]
        ix_local = (ix-1) % x.PN[1] + 1

        pey = (iy-1) ÷ x.PN[2]
        iy_local = (iy-1) % x.PN[2] + 1

        pez = (iz-1) ÷ x.PN[3]
        iz_local = (iz-1) % x.PN[3] + 1

        pet = (it-1) ÷ x.PN[4]
        it_local = (it-1) % x.PN[4] + 1
        myrank = get_myrank((pex,pey,pez,pet),x.PEs)
        return myrank,ix_local,iy_local,iz_local,it_local
    end

    function barrier(x::Gaugefields_4D_wing_mpi)
        MPI.Barrier(comm)
    end

    function Base.setindex!(x::Gaugefields_4D_wing_mpi,v,i1,i2,i3,i4,i5,i6) 
        error("Each element can not be accessed by global index in $(typeof(x)). Use setvalue! function")
        #x.U[i1,i2,i3 + x.NDW,i4 + x.NDW,i5 + x.NDW,i6 + x.NDW] = v
    end

    function Base.getindex(x::Gaugefields_4D_wing_mpi,i1,i2,i3,i4,i5,i6) 
        error("Each element can not be accessed by global index in $(typeof(x)) Use getvalue function")
        #return x.U[i1,i2,i3 .+ x.NDW,i4 .+ x.NDW,i5 .+ x.NDW,i6 .+ x.NDW]
    end

    function Base.setindex!(x::Adjoint_Gaugefields{T},v,i1,i2,i3,i4,i5,i6) where T <: Gaugefields_4D_wing_mpi #U'
        error("type $(typeof(U)) has no setindex method. This type is read only.")
        #x.U[i1,i2,i3 + x.NDW,i4 + x.NDW,i5 + x.NDW,i6 + x.NDW] = v
    end

    function Base.getindex(x::Adjoint_Gaugefields{T},i1,i2,i3,i4,i5,i6) where T <: Gaugefields_4D_wing_mpi #U'
        error("Each element can not be accessed by global index in $(typeof(x)) Use getvalue function")
        #return x.U[i1,i2,i3 .+ x.NDW,i4 .+ x.NDW,i5 .+ x.NDW,i6 .+ x.NDW]
    end

    #=
    function Base.setindex!(U::Shifted_Gaugefields{T,4},v,i1,i2,i3,i4,i5,i6)  where T <: Gaugefields_4D_wing_mpi 
        error("type $(typeof(U)) has no setindex method. This type is read only.")
    end

    function Base.getindex(U::Shifted_Gaugefields{T,4},i1,i2,i3,i4,i5,i6) where T <: Gaugefields_4D_wing_mpi 
        error("Each element can not be accessed by global index in $(typeof(x)) Use getvalue function")
    end
    =#

    #=

    function Base.getindex(U::Adjoint_Gaugefields{Shifted_Gaugefields{T,4}},i1,i2,i3,i4,i5,i6) where T <: Gaugefields_4D_wing_mpi 
        error("Each element can not be accessed by global index in $(typeof(x)) Use getvalue function")
    end

    function Base.setindex!(U::Adjoint_Gaugefields{Shifted_Gaugefields{T,4}},v,i1,i2,i3,i4,i5,i6)  where T <: Gaugefields_4D_wing_mpi 
        error("type $(typeof(U)) has no setindex method. This type is read only.")
    end
    =#


    @inline function getvalue(x::Gaugefields_4D_wing_mpi,i1,i2,i3,i4,i5,i6)
        @inbounds return x.U[i1,i2,i3 .+ x.NDW,i4 .+ x.NDW,i5 .+ x.NDW,i6 .+ x.NDW]
    end

    @inline  function setvalue!(x::Gaugefields_4D_wing_mpi,v,i1,i2,i3,i4,i5,i6)
        @inbounds  x.U[i1,i2,i3 + x.NDW,i4 + x.NDW,i5 + x.NDW,i6 + x.NDW] = v
    end

    @inline  function getvalue(x::Adjoint_Gaugefields{T},i1,i2,i3,i4,i5,i6) where T <: Abstractfields
        @inbounds  return conj(getvalue(x.parent,i2,i1,i3,i4,i5,i6))
    end

    @inline  function setvalue!(x::Adjoint_Gaugefields{T},v,i1,i2,i3,i4,i5,i6) where T <: Abstractfields
        error("type $(typeof(x)) has no setindex method. This type is read only.")
    end

    @inline  function getvalue(U::Shifted_Gaugefields{T,4},i1,i2,i3,i4,i5,i6) where T <: Gaugefields_4D_wing_mpi 
        @inbounds  return U.parent.U[i1,i2,i3 .+ U.parent.NDW .+ U.shift[1],i4 .+ U.parent.NDW .+ U.shift[2],i5 .+ U.parent.NDW .+ U.shift[3],i6 .+ U.parent.NDW .+ U.shift[4]]
    end

    @inline  function setvalue!(U::Shifted_Gaugefields{T,4},v,i1,i2,i3,i4,i5,i6) where T <: Gaugefields_4D_wing_mpi 
        error("type $(typeof(U)) has no setindex method. This type is read only.")
    end

    #=

    @inline  function getvalue(U::Adjoint_Gaugefields{Shifted_Gaugefields{T,4}},i1,i2,i3,i4,i5,i6) where T <: Gaugefields_4D_wing_mpi 
        return conj(getvalue(U.parent,i2,i1,i3,i4,i5,i6))
    end

    @inline function setvalue!(U::Adjoint_Gaugefields{Shifted_Gaugefields{T,4}},v,i1,i2,i3,i4,i5,i6) where T <: Gaugefields_4D_wing_mpi 
        error("type $(typeof(U)) has no setindex method. This type is read only.")
    end

    =#


    function identityGaugefields_4D_wing_mpi(NC,NX,NY,NZ,NT,NDW,PEs;mpiinit = true,verbose_level = 2,randomnumber="Random")
        U = Gaugefields_4D_wing_mpi(NC,NDW,NX,NY,NZ,NT,PEs,mpiinit = mpiinit,verbose_level = verbose_level)
        v = 1

        for it=1:U.PN[4]
            for iz=1:U.PN[3]
                for iy=1:U.PN[2]
                    for ix=1:U.PN[1]
                        @simd for ic=1:NC
                            setvalue!(U,v,ic,ic,ix,iy,iz,it)
                        end
                    end
                end
            end
        end
        #println("setwing")
        set_wing_U!(U)

        return U
    end

    function randomGaugefields_4D_wing_mpi(NC,NX,NY,NZ,NT,NDW,PEs;mpiinit = true,verbose_level= 2,randomnumber="Random")
        U = Gaugefields_4D_wing_mpi(NC,NDW,NX,NY,NZ,NT,PEs,mpiinit = mpiinit,verbose_level = verbose_level)
        v = 1

        for it=1:U.PN[4]
            for iz=1:U.PN[3]
                for iy=1:U.PN[2]
                    for ix=1:U.PN[1]
                        for jc=1:NC
                            @simd for ic=1:NC
                                v = rand()-0.5 + im*(rand()-0.5)
                                setvalue!(U,v,ic,jc,ix,iy,iz,it)
                            end
                        end
                    end
                end
            end
        end
        #println("setwing")
        normalize_U!(U)
        set_wing_U!(U)

        return U
    end

    function clear_U!(U::Gaugefields_4D_wing_mpi{NC}) where NC
        for it=1:U.PN[4]
            for iz=1:U.PN[3]
                for iy=1:U.PN[2]
                    for ix=1:U.PN[1]
                        for jc=1:NC
                            @simd for ic=1:NC
                                v = 0
                                @inbounds setvalue!(U,v,ic,jc,ix,iy,iz,it)
                                #@inbounds Uμ[k1,k2,ix,iy,iz,it] = 0
                            end
                        end
                    end
                end
            end
        end
        set_wing_U!(U)
    end

    function clear_U!(U::Gaugefields_4D_wing_mpi{NC},iseven::Bool) where NC
        for it=1:U.PN[4]
            for iz=1:U.PN[3]
                for iy=1:U.PN[2]
                    for ix=1:U.PN[1]
                        evenodd = ifelse( (ix+iy+iz+it) % 2 ==0, true,false)
                        if evenodd == iseven     
                            for k2=1:NC                            
                                for k1=1:NC
                                    v = 0
                                    @inbounds setvalue!(U,v,k1,k2,ix,iy,iz,it)
                                end
                            end
                        end
                    end
                end
            end
        end
        set_wing_U!(U)
    end

    function clear_U!(U::Gaugefields_4D_wing_mpi{NC},filternumber::N,filterindex::N) where {NC,N <: Integer}
        for it=1:U.PN[4]
            for iz=1:U.PN[3]
                for iy=1:U.PN[2]
                    for ix=1:U.PN[1]
                        filter = ((ix+iy+iz+it)) % filternumber
                        #evenodd = ifelse( (ix+iy+iz+it) % filternumber ==0, true,false)
                        if filter == filterindex 
                            for k2=1:NC                            
                                for k1=1:NC
                                    v = 0
                                    @inbounds setvalue!(U,v,k1,k2,ix,iy,iz,it)
                                end
                            end
                        end
                    end
                end
            end
        end
        set_wing_U!(U)
    end

    function add_U!(c::Gaugefields_4D_wing_mpi{NC},a::T1) where {NC,T1 <: Abstractfields}
        for it=1:c.PN[4]
            for iz=1:c.PN[3]
                for iy=1:c.PN[2]
                    for ix=1:c.PN[1]

                            for k2=1:NC                            
                                @simd for k1=1:NC
                                    av = getvalue(a,k1,k2,ix,iy,iz,it)
                                    cv = getvalue(c,k1,k2,ix,iy,iz,it)
                                    v = cv + av
                                    setvalue!(c,v,k1,k2,ix,iy,iz,it)
                                    #c[k1,k2,ix,iy,iz,it] += a[k1,k2,ix,iy,iz,it]
                                end
                            end
                    end
                end
            end
        end
        #set_wing_U!(c)
    end

    function add_U!(c::Gaugefields_4D_wing_mpi{NC},a::T1,iseven::Bool) where {NC,T1 <: Abstractfields}
        @inbounds for it=1:c.PN[4]
            for iz=1:c.PN[3]
                for iy=1:c.PN[2]
                    for ix=1:c.PN[1]
                        evenodd = ifelse( (ix+iy+iz+it) % 2 ==0, true,false)
                        if evenodd == iseven
                            for k2=1:NC                            
                                @simd for k1=1:NC
                                    av = getvalue(a,k1,k2,ix,iy,iz,it)
                                    cv = getvalue(c,k1,k2,ix,iy,iz,it)
                                    v = cv + av
                                    setvalue!(c,v,k1,k2,ix,iy,iz,it)
                                    #c[k1,k2,ix,iy,iz,it] += a[k1,k2,ix,iy,iz,it]
                                end
                            end
                        end
                    end
                end
            end
        end
        #set_wing_U!(c)
    end

    function add_U!(c::Gaugefields_4D_wing_mpi{NC},α::N,a::T1) where {NC,T1 <: Abstractfields, N<:Number}
        #@inbounds for i=1:length(c.U)
        #    c.U[i] += α*a.U[i]
        #end
        #return 

        NT = c.NT
        NZ = c.NZ
        NY = c.NY
        NX = c.NX
        @inbounds  for it=1:c.PN[4]
            for iz=1:c.PN[3]
                for iy=1:c.PN[2]
                    for ix=1:c.PN[1]
                        for k2=1:NC                            
                            @simd for k1=1:NC
                                v = getvalue(c,k1,k2,ix,iy,iz,it) + α*getvalue(a,k1,k2,ix,iy,iz,it)
                                setvalue!(c,v,k1,k2,ix,iy,iz,it)
                                #c[k1,k2,ix,iy,iz,it] += α*a[k1,k2,ix,iy,iz,it]
                            end
                        end
                    end
                end
            end
        end
        #set_wing_U!(c)
    end

    function substitute_U!(a::Array{T1,1},b::Array{T2,1}) where {T1 <: Gaugefields_4D_wing_mpi,T2 <: Gaugefields_4D_wing_mpi}
        for μ=1:4
            substitute_U!(a[μ],b[μ])
        end
    end

    function substitute_U!(a::Array{T1,1},b::Array{T2,1},iseven::Bool) where {T1 <: Gaugefields_4D_wing_mpi,T2 <: Gaugefields_4D_wing_mpi}
        for μ=1:4
            substitute_U!(a[μ],b[μ],iseven)
        end
    end


    function substitute_U!(U::Gaugefields_4D_wing_mpi{NC},b::T2) where {NC, T2 <: Abstractfields}
        for it=1:U.PN[4]
            for iz=1:U.PN[3]
                for iy=1:U.PN[2]
                    for ix=1:U.PN[1]
                        for k2=1:NC                            
                            for k1=1:NC
                                v = getvalue(b,k1,k2,ix,iy,iz,it)
                                #v = b[k1,k2,ix,iy,iz,it]
                                @inbounds setvalue!(U,v,k1,k2,ix,iy,iz,it)
                            end
                        end
                    end
                end
            end
        end
        set_wing_U!(U)

    end


    function substitute_U!(U::Gaugefields_4D_wing_mpi{NC},b::T2,iseven::Bool) where {NC, T2 <: Abstractfields}
        for it=1:U.PN[4]
            for iz=1:U.PN[3]
                for iy=1:U.PN[2]
                    for ix=1:U.PN[1]
                        evenodd = ifelse( (ix+iy+iz+it) % 2 ==0, true,false)
                        if evenodd == iseven
                            for k2=1:NC                            
                                for k1=1:NC
                                    v = getvalue(b,k1,k2,ix,iy,iz,it)
                                    #v = b[k1,k2,ix,iy,iz,it]
                                    @inbounds setvalue!(U,v,k1,k2,ix,iy,iz,it)
                                end
                            end
                        end
                    end
                end
            end
        end
        set_wing_U!(U)

    end


    function map_U!(U::Gaugefields_4D_wing_mpi{NC},f!::Function,V::Gaugefields_4D_wing_mpi{NC},iseven::Bool) where {NC} 

        A = zeros(ComplexF64,NC,NC)
        B = zeros(ComplexF64,NC,NC)
        for it=1:U.PN[4]
            for iz=1:U.PN[3]
                for iy=1:U.PN[2]
                    for ix=1:U.PN[1]
                        evenodd = ifelse( (ix+iy+iz+it) % 2 ==0, true,false)
                        if evenodd == iseven     
                            for k2=1:NC                            
                                for k1=1:NC
                                    
                                    A[k1,k2] = getvalue(V,k1,k2,ix,iy,iz,it)
                                    B[k1,k2] = getvalue(U,k1,k2,ix,iy,iz,it)
                                end
                            end
                            f!(B,A)
                            for k2=1:NC                            
                                for k1=1:NC
                                    v = B[k1,k2]
                                    setvalue!(U,v,k1,k2,ix,iy,iz,it)
                                    #U[k1,k2,ix,iy,iz,it] = B[k1,k2]
                                end
                            end
                        end
                    end
                end
            end
        end
        set_wing_U!(U)
    end

    function map_U_sequential!(U::Gaugefields_4D_wing_mpi{NC},f!::Function,Uin) where {NC} 
        error("The function map_U_sequential! can not be used with MPI")
    end


    struct Shifted_Gaugefields_4D_mpi{NC,outside} <: Shifted_Gaugefields{NC,4} 
        parent::Gaugefields_4D_wing_mpi{NC}
        #parent::T
        shift::NTuple{4,Int8}
        NX::Int64
        NY::Int64
        NZ::Int64
        NT::Int64
        NDW::Int64

        #function Shifted_Gaugefields(U::T,shift,Dim) where {T <: AbstractGaugefields}
        function Shifted_Gaugefields_4D_mpi(U::Gaugefields_4D_wing_mpi{NC},shift) where NC
            outside = check_outside(U.NDW,shift)
            return new{NC,outside}(U,shift,U.NX,U.NY,U.NZ,U.NT,U.NDW)
        end
    end

    function shift_U(U::Gaugefields_4D_wing_mpi{NC},ν::T) where {T <: Integer,NC}
        if ν == 1
            shift = (1,0,0,0)
        elseif ν == 2
            shift = (0,1,0,0)
        elseif ν == 3
            shift = (0,0,1,0)
        elseif ν == 4
            shift = (0,0,0,1)
        elseif ν == -1
                shift = (-1,0,0,0)
        elseif ν == -2
                shift = (0,-1,0,0)
        elseif ν == -3
                shift = (0,0,-1,0)
        elseif ν == -4
                shift = (0,0,0,-1)
        end

        return Shifted_Gaugefields_4D_mpi(U,shift)
    end

    function shift_U(U::TU,shift::NTuple{Dim,T}) where {Dim,T <: Integer,TU <: Gaugefields_4D_wing_mpi}
        return Shifted_Gaugefields_4D_mpi(U,shift)
    end    


    @inline function getvalue(U::Shifted_Gaugefields_4D_mpi{NC,false},i1,i2,i3,i4,i5,i6) where NC
        #function Base.getindex(U::Shifted_Gaugefields{T,4},i1,i2,i3,i4,i5,i6) where T <: Gaugefields_4D_wing
        @inbounds return getvalue(U.parent,i1,i2,i3 .+ U.shift[1],i4 .+ U.shift[2],i5 .+ U.shift[3],i6 .+ U.shift[4])
    end

    @inline function getvalue(U::Shifted_Gaugefields_4D_mpi{NC,true},i1,i2,i3,i4,i5,i6) where NC
        i3_new = i3 + U.shift[1]
        i3_new += ifelse(i3_new > U.NX + U.NDW,-U.NX,0)
        i3_new += ifelse(i3_new < 1 - U.NDW,U.NX,0)
        i4_new = i4 + U.shift[2]
        i4_new += ifelse(i4_new > U.NY + U.NDW,-U.NY,0)
        i4_new += ifelse(i4_new < 1 - U.NDW,U.NY,0)
        i5_new = i5 + U.shift[3]
        i5_new += ifelse(i5_new > U.NZ + U.NDW,-U.NZ,0)
        i5_new += ifelse(i5_new < 1 - U.NDW,U.NZ,0)
        i6_new = i6 + U.shift[4]
        i6_new += ifelse(i6_new > U.NT + U.NDW,-U.NT,0)
        i6_new += ifelse(i6_new < 1 - U.NDW,U.NT,0)
        #function Base.getindex(U::Shifted_Gaugefields{T,4},i1,i2,i3,i4,i5,i6) where T <: Gaugefields_4D_wing
        @inbounds return getvalue(U.parent,i1,i2,i3_new ,i4_new ,i5_new ,i6_new )
    end
    


    function normalize_U!(U::Gaugefields_4D_wing_mpi{NC}) where NC

        A = zeros(ComplexF64,NC,NC)

        for it=1:U.PN[4]
            for iz=1:U.PN[3]
                for iy=1:U.PN[2]
                    for ix=1:U.PN[1]
                        for jc=1:NC
                            @simd for ic=1:NC
                                A[ic,jc] = getvalue(U,ic,jc,ix,iy,iz,it)
                            end
                        end
                        gramschmidt!(A)

                        for jc=1:NC
                            @simd for ic=1:NC
                                v = A[ic,jc]
                                setvalue!(U,v,ic,jc,ix,iy,iz,it)
                            end
                        end
                    end
                end
            end
        end
        set_wing_U!(U)

    end


    function Base.similar(U::T) where T <: Gaugefields_4D_wing_mpi 
        Uout = Gaugefields_4D_wing_mpi(U.NC,U.NDW,U.NX,U.NY,U.NZ,U.NT,U.PEs,mpiinit=U.mpiinit,verbose_level = U.verbose_print.level)
        #identityGaugefields_4D_wing(U.NC,U.NX,U.NY,U.NZ,U.NT,U.NDW)
        return Uout
    end


    function Base.similar(U::Array{T,1}) where T <: Gaugefields_4D_wing_mpi
        Uout = Array{T,1}(undef,4)
        for μ=1:4
            Uout[μ] = similar(U[μ]) 
        end
        return Uout
    end

    function LinearAlgebra.tr(a::Gaugefields_4D_wing_mpi{NC}) where NC
        NX=a.NX
        NY=a.NY
        NZ=a.NZ
        NT=a.NT
        PN =a.PN

        s = 0
        for it=1:PN[4]
            for iz=1:PN[3]
                for iy=1:PN[2]
                    for ix=1:PN[1]
                        @simd for k=1:NC
                            s += getvalue(a,k,k,ix,iy,iz,it)
                            #println(a[k,k,ix,iy,iz,it])
                        end
                    end
                end
            end
        end

        s = MPI.Allreduce(s,MPI.SUM,comm)

        #println(3*NT*NZ*NY*NX*NC)
        return s
    end

    function partial_tr(a::Gaugefields_4D_wing_mpi{NC},μ) where NC
        error("Polyakov loop is not supported with MPI yet.")
        PN =a.PN

        if μ == 1
            s = 0
            ix = 1
            for it=1:PN[4]
                for iz=1:PN[3]
                    for iy=1:PN[2]
                        #for ix=1:NX
                            @simd for k=1:NC
                                s += getvalue(a,k,k,ix,iy,iz,it)
                                #println(a[k,k,ix,iy,iz,it])
                            end
                        
                        #end
                    end
                end
            end
        elseif μ == 2
            s = 0
            iy =1
            for it=1:PN[4]
                for iz=1:PN[3]
                    #for iy=1:NY
                        for ix=1:PN[1]
                            @simd for k=1:NC
                                s += getvalue(a,k,k,ix,iy,iz,it)
                                #println(a[k,k,ix,iy,iz,it])
                            end
                        end
                    #end
                end
            end
        elseif μ == 3
            s = 0
            iz = 1
            for it=1:PN[4]
                #for iz=1:NZ
                    for iy=1:PN[2]
                        for ix=1:PN[1]
                            @simd for k=1:NC
                                s += getvalue(a,k,k,ix,iy,iz,it)
                                #println(a[k,k,ix,iy,iz,it])
                            end
                        end
                    end
                #end
            end
        else 
            s = 0
            it = 1
                for iz=1:PN[3]
                    for iy=1:PN[2]
                        for ix=1:PN[1]
                            @simd for k=1:NC
                                s += getvalue(a,k,k,ix,iy,iz,it)
                                #println(a[k,k,ix,iy,iz,it])
                            end
                        end
                    end
                end
            
        end

        s = MPI.Allreduce(s,MPI.SUM,comm)
        


        #println(3*NT*NZ*NY*NX*NC)
        return s
    end

    

    function LinearAlgebra.mul!(c::Gaugefields_4D_wing_mpi{NC},a::T1,b::T2) where {NC,T1 <: Abstractfields,T2 <: Abstractfields}
        @assert NC != 2 && NC != 3 "This function is for NC != 2,3"
        NT = c.NT
        NZ = c.NZ
        NY = c.NY
        NX = c.NX
        PN = c.PN
        for it=1:PN[4]
            for iz=1:PN[3]
                for iy=1:PN[2]
                    for ix=1:PN[1]
                        for k2=1:NC                            
                            for k1=1:NC
                                v = 0
                                setvalue!(c,v,k1,k2,ix,iy,iz,it)
                                #c[k1,k2,ix,iy,iz,it] = 0

                                @simd for k3=1:NC
                                    vc = getvalue(c,k1,k2,ix,iy,iz,it) + getvalue(a,k1,k3,ix,iy,iz,it)*getvalue(b,k3,k2,ix,iy,iz,it)
                                    setvalue!(c,vc,k1,k2,ix,iy,iz,it)
                                    #c[k1,k2,ix,iy,iz,it] += a[k1,k3,ix,iy,iz,it]*b[k3,k2,ix,iy,iz,it]
                                end
                            end
                        end
                    end
                end
            end
        end
        #set_wing_U!(c)
    end

    function LinearAlgebra.mul!(c::Gaugefields_4D_wing_mpi{NC},a::T1,b::T2,iseven::Bool) where {NC,T1 <: Abstractfields,T2 <: Abstractfields}
        @assert NC != 2 && NC != 3 "This function is for NC != 2,3"
        NT = c.NT
        NZ = c.NZ
        NY = c.NY
        NX = c.NX
        PN = c.PN
        for it=1:PN[4]
            for iz=1:PN[3]
                for iy=1:PN[2]
                    for ix=1:PN[1]
                        evenodd = ifelse( (ix+iy+iz+it) % 2 ==0, true,false)
                        if evenodd == iseven

                            for k2=1:NC                            
                                for k1=1:NC
                                    v = 0
                                    setvalue!(c,v,k1,k2,ix,iy,iz,it)
                                    #c[k1,k2,ix,iy,iz,it] = 0

                                    @simd for k3=1:NC
                                        vc = getvalue(c,k1,k2,ix,iy,iz,it) + getvalue(a,k1,k3,ix,iy,iz,it)*getvalue(b,k3,k2,ix,iy,iz,it)
                                        setvalue!(c,vc,k1,k2,ix,iy,iz,it)
                                        #c[k1,k2,ix,iy,iz,it] += a[k1,k3,ix,iy,iz,it]*b[k3,k2,ix,iy,iz,it]
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        #set_wing_U!(c)
    end

    function mul_skiplastindex!(c::Gaugefields_4D_wing_mpi{NC},a::T1,b::T2) where {NC,T1 <: Abstractfields,T2 <: Abstractfields}
        #@assert NC != 2 && NC != 3 "This function is for NC != 2,3"
        NT = c.NT
        NZ = c.NZ
        NY = c.NY
        NX = c.NX
        #for it=1:NT
        it = 1
        PN = c.PN
            for iz=1:PN[3]
                for iy=1:PN[2]
                    for ix=1:PN[1]
                        for k2=1:NC                            
                            for k1=1:NC
                                v = 0
                                setvalue!(c,v,k1,k2,ix,iy,iz,it)
                                #c[k1,k2,ix,iy,iz,it] = 0

                                @simd for k3=1:NC
                                    av = getvalue(a,k1,k3,ix,iy,iz,it)
                                    bv = getvalue(b,k3,k2,ix,iy,iz,it)
                                    cv = getvalue(c,k1,k2,ix,iy,iz,it)

                                    v = cv + av + bv
                                    setvalue!(c,v,k1,k2,ix,iy,iz,it)
                                    #c[k1,k2,ix,iy,iz,it] += a[k1,k3,ix,iy,iz,it]*b[k3,k2,ix,iy,iz,it]
                                end
                            end
                        end
                    end
                end
            end
        #end
        set_wing_U!(c)
    end
    

    function LinearAlgebra.mul!(c::Gaugefields_4D_wing_mpi{3},a::T1,b::T2) where {NC,T1 <: Abstractfields,T2 <: Abstractfields}
        #@assert NC != 2 && NC != 3 "This function is for NC != 2,3"
        NT = c.NT
        NZ = c.NZ
        NY = c.NY
        NX = c.NX
        PN = c.PN
        for it=1:PN[4]
            for iz=1:PN[3]
                for iy=1:PN[2]
                    for ix=1:PN[1]
                        a11 = getvalue(a,1,1,ix,iy,iz,it)
                        a21 = getvalue(a,2,1,ix,iy,iz,it)
                        a31 = getvalue(a,3,1,ix,iy,iz,it)
                        a12 = getvalue(a,1,2,ix,iy,iz,it)
                        a22 = getvalue(a,2,2,ix,iy,iz,it)
                        a32 = getvalue(a,3,2,ix,iy,iz,it)
                        a13 = getvalue(a,1,3,ix,iy,iz,it)
                        a23 = getvalue(a,2,3,ix,iy,iz,it)
                        a33 = getvalue(a,3,3,ix,iy,iz,it)
                        b11 = getvalue(b,1,1,ix,iy,iz,it)
                        b21 = getvalue(b,2,1,ix,iy,iz,it)
                        b31 = getvalue(b,3,1,ix,iy,iz,it)
                        b12 = getvalue(b,1,2,ix,iy,iz,it)
                        b22 = getvalue(b,2,2,ix,iy,iz,it)
                        b32 = getvalue(b,3,2,ix,iy,iz,it)
                        b13 = getvalue(b,1,3,ix,iy,iz,it)
                        b23 = getvalue(b,2,3,ix,iy,iz,it)
                        b33 = getvalue(b,3,3,ix,iy,iz,it)


                        v = (a11*b11+a12*b21+a13*b31)
                        setvalue!(c,v,1,1,ix,iy,iz,it) 
                        v =  (a21*b11+a22*b21+a23*b31)
                        setvalue!(c,v,2,1,ix,iy,iz,it) 
                        v = (a31*b11+a32*b21+a33*b31)
                        setvalue!(c,v,3,1,ix,iy,iz,it) 
                        v = (a11*b12+a12*b22+a13*b32)
                        setvalue!(c,v,1,2,ix,iy,iz,it) 
                        v = (a21*b12+a22*b22+a23*b32)
                        setvalue!(c,v,2,2,ix,iy,iz,it) 
                        v = (a31*b12+a32*b22+a33*b32)
                        setvalue!(c,v,3,2,ix,iy,iz,it) 
                        v = (a11*b13+a12*b23+a13*b33)
                        setvalue!(c,v,1,3,ix,iy,iz,it) 
                        v =  (a21*b13+a22*b23+a23*b33)
                        setvalue!(c,v,2,3,ix,iy,iz,it) 
                        v = (a31*b13+a32*b23+a33*b33)
                        setvalue!(c,v,3,3,ix,iy,iz,it) 
                    end
                end
            end
        end
        #set_wing_U!(c)
    end

    function LinearAlgebra.mul!(c::Gaugefields_4D_wing_mpi{3},a::T1,b::T2,iseven::Bool) where {NC,T1 <: Abstractfields,T2 <: Abstractfields}
        #@assert NC != 2 && NC != 3 "This function is for NC != 2,3"
        NT = c.NT
        NZ = c.NZ
        NY = c.NY
        NX = c.NX
        PN = c.PN
        for it=1:PN[4]
            for iz=1:PN[3]
                for iy=1:PN[2]
                    for ix=1:PN[1]
                        evenodd = ifelse( (ix+iy+iz+it) % 2 ==0, true,false)
                        if evenodd == iseven

                            a11 = getvalue(a,1,1,ix,iy,iz,it)
                            a21 = getvalue(a,2,1,ix,iy,iz,it)
                            a31 = getvalue(a,3,1,ix,iy,iz,it)
                            a12 = getvalue(a,1,2,ix,iy,iz,it)
                            a22 = getvalue(a,2,2,ix,iy,iz,it)
                            a32 = getvalue(a,3,2,ix,iy,iz,it)
                            a13 = getvalue(a,1,3,ix,iy,iz,it)
                            a23 = getvalue(a,2,3,ix,iy,iz,it)
                            a33 = getvalue(a,3,3,ix,iy,iz,it)
                            b11 = getvalue(b,1,1,ix,iy,iz,it)
                            b21 = getvalue(b,2,1,ix,iy,iz,it)
                            b31 = getvalue(b,3,1,ix,iy,iz,it)
                            b12 = getvalue(b,1,2,ix,iy,iz,it)
                            b22 = getvalue(b,2,2,ix,iy,iz,it)
                            b32 = getvalue(b,3,2,ix,iy,iz,it)
                            b13 = getvalue(b,1,3,ix,iy,iz,it)
                            b23 = getvalue(b,2,3,ix,iy,iz,it)
                            b33 = getvalue(b,3,3,ix,iy,iz,it)


                            v = (a11*b11+a12*b21+a13*b31)
                            setvalue!(c,v,1,1,ix,iy,iz,it) 
                            v =  (a21*b11+a22*b21+a23*b31)
                            setvalue!(c,v,2,1,ix,iy,iz,it) 
                            v = (a31*b11+a32*b21+a33*b31)
                            setvalue!(c,v,3,1,ix,iy,iz,it) 
                            v = (a11*b12+a12*b22+a13*b32)
                            setvalue!(c,v,1,2,ix,iy,iz,it) 
                            v = (a21*b12+a22*b22+a23*b32)
                            setvalue!(c,v,2,2,ix,iy,iz,it) 
                            v = (a31*b12+a32*b22+a33*b32)
                            setvalue!(c,v,3,2,ix,iy,iz,it) 
                            v = (a11*b13+a12*b23+a13*b33)
                            setvalue!(c,v,1,3,ix,iy,iz,it) 
                            v =  (a21*b13+a22*b23+a23*b33)
                            setvalue!(c,v,2,3,ix,iy,iz,it) 
                            v = (a31*b13+a32*b23+a33*b33)
                            setvalue!(c,v,3,3,ix,iy,iz,it) 
                        end
                    end
                end
            end
        end
        #set_wing_U!(c)
    end

    function LinearAlgebra.mul!(c::Gaugefields_4D_wing_mpi{2},a::T1,b::T2) where {NC,T1 <: Abstractfields,T2 <: Abstractfields}
        #@assert NC != 2 && NC != 3 "This function is for NC != 2,3"
        NT = c.NT
        NZ = c.NZ
        NY = c.NY
        NX = c.NX
        PN = c.PN
        for it=1:PN[4]
            for iz=1:PN[3]
                for iy=1:PN[2]
                    for ix=1:PN[1]
                        a11 = getvalue(a,1,1,ix,iy,iz,it)
                        a21 = getvalue(a,2,1,ix,iy,iz,it)
                        
                        a12 = getvalue(a,1,2,ix,iy,iz,it)
                        a22 = getvalue(a,2,2,ix,iy,iz,it)


                        b11 = getvalue(b,1,1,ix,iy,iz,it)
                        b21 = getvalue(b,2,1,ix,iy,iz,it)

                        b12 = getvalue(b,1,2,ix,iy,iz,it)
                        b22 = getvalue(b,2,2,ix,iy,iz,it)



                        v = a11*b11+a12*b21
                        setvalue!(c,v,1,1,ix,iy,iz,it) 
                        v = a21*b11+a22*b21
                        setvalue!(c,v,2,1,ix,iy,iz,it) 

                        v = a11*b12+a12*b22
                        setvalue!(c,v,1,2,ix,iy,iz,it) 
                        v = a21*b12+a22*b22
                        setvalue!(c,v,2,2,ix,iy,iz,it) 
                        #v = a31*b12+a32*b22

                    end
                end
            end
        end
        #set_wing_U!(c)
    end

    function LinearAlgebra.mul!(c::Gaugefields_4D_wing_mpi{2},a::T1,b::T2,iseven::Bool) where {NC,T1 <: Abstractfields,T2 <: Abstractfields}
        #@assert NC != 2 && NC != 3 "This function is for NC != 2,3"
        NT = c.NT
        NZ = c.NZ
        NY = c.NY
        NX = c.NX
        PN = c.PN
        for it=1:PN[4]
            for iz=1:PN[3]
                for iy=1:PN[2]
                    for ix=1:PN[1]
                        evenodd = ifelse( (ix+iy+iz+it) % 2 ==0, true,false)
                        if evenodd == iseven


                            a11 = getvalue(a,1,1,ix,iy,iz,it)
                            a21 = getvalue(a,2,1,ix,iy,iz,it)
                            
                            a12 = getvalue(a,1,2,ix,iy,iz,it)
                            a22 = getvalue(a,2,2,ix,iy,iz,it)


                            b11 = getvalue(b,1,1,ix,iy,iz,it)
                            b21 = getvalue(b,2,1,ix,iy,iz,it)

                            b12 = getvalue(b,1,2,ix,iy,iz,it)
                            b22 = getvalue(b,2,2,ix,iy,iz,it)



                            v = a11*b11+a12*b21
                            setvalue!(c,v,1,1,ix,iy,iz,it) 
                            v = a21*b11+a22*b21
                            setvalue!(c,v,2,1,ix,iy,iz,it) 

                            v = a11*b12+a12*b22
                            setvalue!(c,v,1,2,ix,iy,iz,it) 
                            v = a21*b12+a22*b22
                            setvalue!(c,v,2,2,ix,iy,iz,it) 
                            v = a31*b12+a32*b22
                        end

                    end
                end
            end
        end
        #set_wing_U!(c)
    end

    function LinearAlgebra.mul!(c::Gaugefields_4D_wing_mpi{NC},a::T1,b::T2,α::Ta,β::Tb) where {NC,T1 <: Abstractfields,T2 <: Abstractfields,Ta <: Number, Tb <: Number}
        @assert NC != 2 && NC != 3 "This function is for NC != 2,3"
        NT = c.NT
        NZ = c.NZ
        NY = c.NY
        NX = c.NX
        PN = c.PN
        for it=1:PN[4]
            for iz=1:PN[3]
                for iy=1:PN[2]
                    for ix=1:PN[1]
                        for k2=1:NC                            
                            for k1=1:NC
                                v = β*getvalue(c,k1,k2,ix,iy,iz,it)
                                setvalue!(c,v,k1,k2,ix,iy,iz,it)
                                #c[k1,k2,ix,iy,iz,it] = β*c[k1,k2,ix,iy,iz,it] 
                                @simd for k3=1:NC
                                    vc = getvalue(c,k1,k2,ix,iy,iz,it) + α*getvalue(a,k1,k3,ix,iy,iz,it)*getvalue(b,k3,k2,ix,iy,iz,it)
                                    setvalue!(c,vc,k1,k2,ix,iy,iz,it)
                                    #c[k1,k2,ix,iy,iz,it] += α*a[k1,k3,ix,iy,iz,it]*b[k3,k2,ix,iy,iz,it] 
                                end
                            end
                        end
                    end
                end
            end
        end
        #set_wing_U!(c)
    end

    function LinearAlgebra.mul!(c::Gaugefields_4D_wing_mpi{2},a::T1,b::T2,α::Ta,β::Tb) where {NC,T1 <: Abstractfields,T2 <: Abstractfields,Ta <: Number, Tb <: Number}
        #@assert NC != 2 && NC != 3 "This function is for NC != 2,3"
        NT = c.NT
        NZ = c.NZ
        NY = c.NY
        NX = c.NX
        PN = c.PN
        if β == zero(β)
            if α == one(α)
                mul!(c,a,b)
                return
            end
        end


        @inbounds for it=1:PN[4]
            for iz=1:PN[3]
                for iy=1:PN[2]
                    @simd for ix=1:PN[1]
                        a11 = getvalue(a,1,1,ix,iy,iz,it)
                        a21 = getvalue(a,2,1,ix,iy,iz,it)
                        a12 = getvalue(a,1,2,ix,iy,iz,it)
                        a22 = getvalue(a,2,2,ix,iy,iz,it)

                        b11 = getvalue(b,1,1,ix,iy,iz,it)
                        b21 = getvalue(b,2,1,ix,iy,iz,it)
                        b12 = getvalue(b,1,2,ix,iy,iz,it)
                        b22 = getvalue(b,2,2,ix,iy,iz,it)


                        v = (a11*b11+a12*b21)*α + β*getvalue(c,1,1,ix,iy,iz,it)
                        setvalue!(c,v,1,1,ix,iy,iz,it) 
                        v =  (a21*b11+a22*b21)*α + β*getvalue(c,2,1,ix,iy,iz,it)
                        setvalue!(c,v,2,1,ix,iy,iz,it) 
                        v = (a11*b12+a12*b22)*α + β*getvalue(c,1,2,ix,iy,iz,it)
                        setvalue!(c,v,1,2,ix,iy,iz,it) 
                        v = (a21*b12+a22*b22)*α + β*getvalue(c,2,2,ix,iy,iz,it)
                        setvalue!(c,v,2,2,ix,iy,iz,it) 


                    end
                end
            end
        end
        #set_wing_U!(c)
    end

    function LinearAlgebra.mul!(c::Gaugefields_4D_wing_mpi{3},a::T1,b::T2,α::Ta,β::Tb) where {NC,T1 <: Abstractfields,T2 <: Abstractfields,Ta <: Number, Tb <: Number}
        #@assert NC != 2 && NC != 3 "This function is for NC != 2,3"
        NT = c.NT
        NZ = c.NZ
        NY = c.NY
        NX = c.NX
        PN = c.PN
        if β == zero(β)
            if α == one(α)
                mul!(c,a,b)
                return
            end
        end


        @inbounds for it=1:PN[4]
            for iz=1:PN[3]
                for iy=1:PN[2]
                    @simd for ix=1:PN[1]
                        a11 = getvalue(a,1,1,ix,iy,iz,it)
                        a21 = getvalue(a,2,1,ix,iy,iz,it)
                        a31 = getvalue(a,3,1,ix,iy,iz,it)
                        a12 = getvalue(a,1,2,ix,iy,iz,it)
                        a22 = getvalue(a,2,2,ix,iy,iz,it)
                        a32 = getvalue(a,3,2,ix,iy,iz,it)
                        a13 = getvalue(a,1,3,ix,iy,iz,it)
                        a23 = getvalue(a,2,3,ix,iy,iz,it)
                        a33 = getvalue(a,3,3,ix,iy,iz,it)
                        b11 = getvalue(b,1,1,ix,iy,iz,it)
                        b21 = getvalue(b,2,1,ix,iy,iz,it)
                        b31 = getvalue(b,3,1,ix,iy,iz,it)
                        b12 = getvalue(b,1,2,ix,iy,iz,it)
                        b22 = getvalue(b,2,2,ix,iy,iz,it)
                        b32 = getvalue(b,3,2,ix,iy,iz,it)
                        b13 = getvalue(b,1,3,ix,iy,iz,it)
                        b23 = getvalue(b,2,3,ix,iy,iz,it)
                        b33 = getvalue(b,3,3,ix,iy,iz,it)

                        v = (a11*b11+a12*b21+a13*b31)*α + β*getvalue(c,1,1,ix,iy,iz,it)
                        setvalue!(c,v,1,1,ix,iy,iz,it) 
                        v =  (a21*b11+a22*b21+a23*b31)*α + β*getvalue(c,2,1,ix,iy,iz,it)
                        setvalue!(c,v,2,1,ix,iy,iz,it) 
                        v = (a31*b11+a32*b21+a33*b31)*α + β*getvalue(c,3,1,ix,iy,iz,it)
                        setvalue!(c,v,3,1,ix,iy,iz,it) 
                        v = (a11*b12+a12*b22+a13*b32)*α + β*getvalue(c,1,2,ix,iy,iz,it)
                        setvalue!(c,v,1,2,ix,iy,iz,it) 
                        v = (a21*b12+a22*b22+a23*b32)*α + β*getvalue(c,2,2,ix,iy,iz,it)
                        setvalue!(c,v,2,2,ix,iy,iz,it) 
                        v = (a31*b12+a32*b22+a33*b32)*α + β*getvalue(c,3,2,ix,iy,iz,it)
                        setvalue!(c,v,3,2,ix,iy,iz,it) 
                        v = (a11*b13+a12*b23+a13*b33)*α + β*getvalue(c,1,3,ix,iy,iz,it)
                        setvalue!(c,v,1,3,ix,iy,iz,it) 
                        v =  (a21*b13+a22*b23+a23*b33)*α + β*getvalue(c,2,3,ix,iy,iz,it)
                        setvalue!(c,v,2,3,ix,iy,iz,it) 
                        v = (a31*b13+a32*b23+a33*b33)*α + β*getvalue(c,3,3,ix,iy,iz,it)
                        setvalue!(c,v,3,3,ix,iy,iz,it) 


                    end
                end
            end
        end
    end

    function set_wing_U!(u::Array{Gaugefields_4D_wing_mpi{NC},1}) where NC
        for μ=1:4
            set_wing_U!(u[μ]) 
        end
    end

    function set_wing_U!(u::Gaugefields_4D_wing_mpi{NC}) where NC
        NT = u.NT
        NY = u.NY
        NZ = u.NZ
        NX = u.NX
        NDW = u.NDW
        PEs = u.PEs
        PN = u.PN
        myrank = u.myrank
        myrank_xyzt = u.myrank_xyzt
        myrank_xyzt_send = u.myrank_xyzt
        
    
        #X direction 
        #Now we send data
        #from NX to 1
        N = PN[2]*PN[3]*PN[4]*NDW*NC*NC
        send_mesg1 = Array{ComplexF64}(undef, N)
        recv_mesg1 = Array{ComplexF64}(undef, N)

        count = 0
        for it=1:PN[4]
            for iz=1:PN[3]
                for iy=1:PN[2]
                    for id=1:NDW
                        for k2=1:NC
                            for k1=1:NC
                                count += 1
                                send_mesg1[count] = getvalue(u,k1,k2,PN[1]+(id-NDW),iy,iz,it)
                                #u[k1,k2,-NDW+id,iy,iz,it] = u[k1,k2,NX+(id-NDW),iy,iz,it]
                            end
                        end
                    end
                end
            end
        end

        px = myrank_xyzt[1] + 1
        px += ifelse(px >= PEs[1],-PEs[1],0)        
        myrank_xyzt_send = (px,myrank_xyzt[2],myrank_xyzt[3],myrank_xyzt[4])
        myrank_send1 = get_myrank(myrank_xyzt_send,PEs)
        #=
        for ip=0:u.nprocs-1
            if ip == u.myrank
                println("rank = $myrank, myrank_send1 = $(myrank_send1)")
            end
            MPI.Barrier(comm)

        end
        =#
        
        sreq1 = MPI.Isend(send_mesg1, myrank_send1, myrank_send1+32, comm) #from left to right 0 -> 1

        N = PN[2]*PN[3]*PN[4]*NDW*NC*NC
        send_mesg2 = Array{ComplexF64}(undef, N)
        recv_mesg2 = Array{ComplexF64}(undef, N)

        count = 0
        for it=1:PN[4]
            for iz=1:PN[3]
                for iy=1:PN[2]
                    for id=1:NDW
                        for k2=1:NC
                            for k1=1:NC
                                count += 1
                                send_mesg2[count] = getvalue(u,k1,k2,id,iy,iz,it)
                            end
                        end
                    end
                end
            end
        end
        px = myrank_xyzt[1] - 1
        px += ifelse(px < 0,PEs[1],0)
        #println("px = $px")        
        myrank_xyzt_send = (px,myrank_xyzt[2],myrank_xyzt[3],myrank_xyzt[4])
        myrank_send2 = get_myrank(myrank_xyzt_send,PEs)
        #=
        for ip=0:u.nprocs-1
            if ip == u.myrank
                println("rank = $myrank, myrank_send2 = $(myrank_send2)")
            end
            MPI.Barrier(comm)

        end
        =#


        
        sreq2 = MPI.Isend(send_mesg2, myrank_send2, myrank_send2+64, comm) #from right to left 0 -> -1

        #=
        myrank = 1: myrank_send1 = 2, myrank_send2 = 0
            sreq1: from 1 to 2 2
            sreq2: from 1 to 0 2
        myrank = 2: myrank_send1 = 3, myrank_send2 = 1
            sreq1: from 2 to 3 3
            sreq2: from 2 to 1 1
            rreq1: from 1 to 2 2 -> sreq1 at myrank 1
            rreq2: from 3 to 2 2 
        myrank = 3: myrank_send1 = 4, myrank_send2 = 2
            sreq1: from 3 to 4 4
            sreq2: from 3 to 2 2
        =#

        rreq1 = MPI.Irecv!(recv_mesg1, myrank_send2, myrank+32, comm) #from -1 to 0
        rreq2 = MPI.Irecv!(recv_mesg2, myrank_send1, myrank+64, comm) #from 1 to 0

        stats = MPI.Waitall!([rreq1, sreq1,rreq2,sreq2])
        MPI.Barrier(comm)

        count = 0
        for it=1:PN[4]
            for iz=1:PN[3]
                for iy=1:PN[2]
                    for id=1:NDW
                        for k2=1:NC
                            for k1=1:NC
                                count += 1
                                v = recv_mesg1[count]
                                setvalue!(u,v,k1,k2,-NDW+id,iy,iz,it)
                                #send_mesg1[count] = getvalue(u,k1,k2,PN[1]+(id-NDW),iy,iz,it)
                                #u[k1,k2,-NDW+id,iy,iz,it] = u[k1,k2,NX+(id-NDW),iy,iz,it]
                            end
                        end
                    end
                end
            end
        end

        count = 0
        for it=1:PN[4]
            for iz=1:PN[3]
                for iy=1:PN[2]
                    for id=1:NDW
                        for k2=1:NC
                            for k1=1:NC
                                count += 1
                                v = recv_mesg2[count]
                                setvalue!(u,v,k1,k2,PN[1]+id,iy,iz,it)
                                #u[k1,k2,NX+id,iy,iz,it] = u[k1,k2,id,iy,iz,it]
                                #send_mesg2[count] = getvalue(u,k1,k2,id,iy,iz,it)
                            end
                        end
                    end
                end
            end
        end


        #N = PN[1]*PN[3]*PN[4]*NDW*NC*NC
        N = PN[4]*PN[3]*length(-NDW+1:PN[1]+NDW)*NDW*NC*NC
        send_mesg1 = Array{ComplexF64}(undef, N)
        recv_mesg1 = Array{ComplexF64}(undef, N)
        send_mesg2 = Array{ComplexF64}(undef, N)
        recv_mesg2 = Array{ComplexF64}(undef, N)

        #Y direction 
        #Now we send data
        count = 0
        for it=1:PN[4]
            for iz=1:PN[3]
                for ix=-NDW+1:PN[1]+NDW
                    for id=1:NDW
                        for k1=1:NC
                            for k2=1:NC
                                count += 1
                                send_mesg1[count] = getvalue(u,k1,k2,ix,PN[2]+(id-NDW),iz,it)
                                #u[k1,k2,ix,-NDW+id,iz,it] = u[k1,k2,ix,NY+(id-NDW),iz,it]
                            end
                        end
                    end
                end
            end
        end

        py = myrank_xyzt[2] + 1
        py += ifelse(py >= PEs[2],-PEs[2],0)        
        myrank_xyzt_send = (myrank_xyzt[1],py,myrank_xyzt[3],myrank_xyzt[4])
        myrank_send1 = get_myrank(myrank_xyzt_send,PEs)
        #println("rank = $rank, myrank_send1 = $(myrank_send1)")
        sreq1 = MPI.Isend(send_mesg1, myrank_send1, myrank_send1+32, comm) #from left to right 0 -> 1

    
        count = 0
        for it=1:PN[4]
            for iz=1:PN[3]
                for ix=-NDW+1:PN[1]+NDW
                    for id=1:NDW
                        for k1=1:NC
                            for k2=1:NC
                                count += 1
                                send_mesg2[count] = getvalue(u,k1,k2,ix,id,iz,it)
                                #u[k1,k2,ix,NY+id,iz,it] = u[k1,k2,ix,id,iz,it]
                            end
                        end
                    end
                end
            end
        end

        py = myrank_xyzt[2] - 1
        py += ifelse(py < 0,PEs[2],0)
        #println("py = $py")        
        myrank_xyzt_send = (myrank_xyzt[1],py,myrank_xyzt[3],myrank_xyzt[4])
        myrank_send2 = get_myrank(myrank_xyzt_send,PEs)
        #println("rank = $rank, myrank_send2 = $(myrank_send2)")
        sreq2 = MPI.Isend(send_mesg2, myrank_send2, myrank_send2+64, comm) #from right to left 0 -> -1

        rreq1 = MPI.Irecv!(recv_mesg1, myrank_send2, myrank+32, comm) #from -1 to 0
        rreq2 = MPI.Irecv!(recv_mesg2, myrank_send1, myrank+64, comm) #from 1 to 0

        stats = MPI.Waitall!([rreq1, sreq1,rreq2,sreq2])

        count = 0
        for it=1:PN[4]
            for iz=1:PN[3]
                for ix=-NDW+1:PN[1]+NDW
                    for id=1:NDW
                        for k1=1:NC
                            for k2=1:NC
                                count += 1
                                v = recv_mesg1[count] 
                                setvalue!(u,v,k1,k2,ix,-NDW+id,iz,it)
                                #send_mesg1[count] = getvalue(u,k1,k2,ix,PN[2]+(id-NDW),iz,it)
                                #u[k1,k2,ix,-NDW+id,iz,it] = u[k1,k2,ix,NY+(id-NDW),iz,it]
                            end
                        end
                    end
                end
            end
        end

        count = 0
        for it=1:PN[4]
            for iz=1:PN[3]
                for ix=-NDW+1:PN[1]+NDW
                    for id=1:NDW
                        for k1=1:NC
                            for k2=1:NC
                                count += 1
                                v = recv_mesg2[count]
                                setvalue!(u,v,k1,k2,ix,PN[2]+id,iz,it)
                                #send_mesg2[count] = getvalue(u,k1,k2,ix,id,iz,it)
                                #u[k1,k2,ix,NY+id,iz,it] = u[k1,k2,ix,id,iz,it]
                            end
                        end
                    end
                end
            end
        end


        MPI.Barrier(comm)

        #Z direction 
        #Now we send data

        N = NDW*PN[4]*length(-NDW+1:PN[2]+NDW)*length(-NDW+1:PN[1]+NDW)*NC*NC
        send_mesg1 = Array{ComplexF64}(undef, N)
        recv_mesg1 = Array{ComplexF64}(undef, N)
        send_mesg2 = Array{ComplexF64}(undef, N)
        recv_mesg2 = Array{ComplexF64}(undef, N)

        count = 0
        for id=1:NDW
            for it=1:PN[4]
                for iy=-NDW+1:PN[2]+NDW
                    for ix=-NDW+1:PN[1]+NDW
                        for k1=1:NC
                            for k2=1:NC
                                count += 1
                                send_mesg1[count] = getvalue(u,k1,k2,ix,iy,PN[3]+(id-NDW),it)
                                send_mesg2[count] = getvalue(u,k1,k2,ix,iy,id,it)
                                #u[k1,k2,ix,iy,id-NDW,it] = u[k1,k2,ix,iy,NZ+(id-NDW),it]
                                #u[k1,k2,ix,iy,NZ+id,it] = u[k1,k2,ix,iy,id,it]
                            end
                        end
                    end
                end
            end
        end

        pz = myrank_xyzt[3] + 1
        pz += ifelse(pz >= PEs[3],-PEs[3],0)        
        myrank_xyzt_send = (myrank_xyzt[1],myrank_xyzt[2],pz,myrank_xyzt[4])
        myrank_send1 = get_myrank(myrank_xyzt_send,PEs)
        #println("rank = $rank, myrank_send1 = $(myrank_send1)")
        sreq1 = MPI.Isend(send_mesg1, myrank_send1, myrank_send1+32, comm) #from left to right 0 -> 1

        pz = myrank_xyzt[3] - 1
        pz += ifelse(pz < 0,PEs[3],0)
        #println("pz = $pz")        
        myrank_xyzt_send = (myrank_xyzt[1],myrank_xyzt[2],pz,myrank_xyzt[4])
        myrank_send2 = get_myrank(myrank_xyzt_send,PEs)
        #println("rank = $rank, myrank_send2 = $(myrank_send2)")
        sreq2 = MPI.Isend(send_mesg2, myrank_send2, myrank_send2+64, comm) #from right to left 0 -> -1

        rreq1 = MPI.Irecv!(recv_mesg1, myrank_send2, myrank+32, comm) #from -1 to 0
        rreq2 = MPI.Irecv!(recv_mesg2, myrank_send1, myrank+64, comm) #from 1 to 0

        stats = MPI.Waitall!([rreq1, sreq1,rreq2,sreq2])

        count = 0
        for id=1:NDW
            for it=1:PN[4]
                for iy=-NDW+1:PN[2]+NDW
                    for ix=-NDW+1:PN[1]+NDW
                        for k1=1:NC
                            for k2=1:NC
                                count += 1
                                v = recv_mesg1[count]
                                setvalue!(u,v,k1,k2,ix,iy,id-NDW,it)
                                v = recv_mesg2[count]
                                setvalue!(u,v,k1,k2,ix,iy,PN[3]+id,it)
                                #u[k1,k2,ix,iy,id-NDW,it] = u[k1,k2,ix,iy,NZ+(id-NDW),it]
                                #u[k1,k2,ix,iy,NZ+id,it] = u[k1,k2,ix,iy,id,it]
                            end
                        end
                    end
                end
            end
        end

        MPI.Barrier(comm)
        
        #T direction 
        #Now we send data

        N = NDW*length(-NDW+1:PN[3]+NDW)*length(-NDW+1:PN[2]+NDW)*length(-NDW+1:PN[1]+NDW)*NC*NC
        send_mesg1 = Array{ComplexF64}(undef, N)
        recv_mesg1 = Array{ComplexF64}(undef, N)
        send_mesg2 = Array{ComplexF64}(undef, N)
        recv_mesg2 = Array{ComplexF64}(undef, N)
    
        count = 0
        for id=1:NDW
            for iz=-NDW+1:PN[3]+NDW
                for iy=-NDW+1:PN[2]+NDW
                    for ix=-NDW+1:PN[1]+NDW
                        for k1=1:NC
                            for k2=1:NC
                                count += 1
                                send_mesg1[count] = getvalue(u,k1,k2,ix,iy,iz,PN[4]+(id-NDW))
                                send_mesg2[count] = getvalue(u,k1,k2,ix,iy,iz,id)
                                #u[k1,k2,ix,iy,iz,id-NDW] = u[k1,k2,ix,iy,iz,PN[4]+(id-NDW)]
                                #u[k1,k2,ix,iy,iz,PN[4]+id] = u[k1,k2,ix,iy,iz,id]
                            end
                        end
                    end
                end
            end
        end

        pt = myrank_xyzt[4] + 1
        pt += ifelse(pt >= PEs[4],-PEs[4],0)        
        myrank_xyzt_send = (myrank_xyzt[1],myrank_xyzt[2],myrank_xyzt[3],pt)
        myrank_send1 = get_myrank(myrank_xyzt_send,PEs)
        #println("rank = $rank, myrank_send1 = $(myrank_send1)")
        sreq1 = MPI.Isend(send_mesg1, myrank_send1, myrank_send1+32, comm) #from left to right 0 -> 1

        pt = myrank_xyzt[4] - 1
        pt += ifelse(pt < 0,PEs[4],0)
        #println("pt = $pt")        
        myrank_xyzt_send = (myrank_xyzt[1],myrank_xyzt[2],myrank_xyzt[3],pt)
        myrank_send2 = get_myrank(myrank_xyzt_send,PEs)
        #println("rank = $rank, myrank_send2 = $(myrank_send2)")
        sreq2 = MPI.Isend(send_mesg2, myrank_send2, myrank_send2+64, comm) #from right to left 0 -> -1

        rreq1 = MPI.Irecv!(recv_mesg1, myrank_send2, myrank+32, comm) #from -1 to 0
        rreq2 = MPI.Irecv!(recv_mesg2, myrank_send1, myrank+64, comm) #from 1 to 0

        stats = MPI.Waitall!([rreq1, sreq1,rreq2,sreq2])

        count = 0
        for id=1:NDW
            for iz=-NDW+1:PN[3]+NDW
                for iy=-NDW+1:PN[2]+NDW
                    for ix=-NDW+1:PN[1]+NDW
                        for k1=1:NC
                            for k2=1:NC
                                count += 1
                                v = recv_mesg1[count]
                                setvalue!(u,v,k1,k2,ix,iy,iz,id-NDW)
                                v = recv_mesg2[count]
                                setvalue!(u,v,k1,k2,ix,iy,iz,PN[4]+id)

                                #send_mesg1[count] = getvalue(u,k1,k2,ix,iy,iz,PN[4]+(id-NDW))
                                #send_mesg2[count] = getvalue(u,k1,k2,ix,iy,iz,id)
                                #u[k1,k2,ix,iy,iz,id-NDW] = u[k1,k2,ix,iy,iz,PN[4]+(id-NDW)]
                                #u[k1,k2,ix,iy,iz,PN[4]+id] = u[k1,k2,ix,iy,iz,id]
                            end
                        end
                    end
                end
            end
        end
        #error("rr22r")


        MPI.Barrier(comm)
    
        return
    end


    

#end