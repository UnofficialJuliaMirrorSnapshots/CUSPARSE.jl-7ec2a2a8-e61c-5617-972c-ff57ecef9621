using CUSPARSE
using CUDArt
using Base.Test

m = 25
n = 35
k = 10
blockdim = 5

@testset "util" begin
    x = sprand(m,n,0.2)
    d_x = CudaSparseMatrixCSC(x)
    @test device(x)   == -1
    @test length(d_x) == m*n
    @test size(d_x)   == (m,n)
    @test size(d_x,1) == m
    @test size(d_x,2) == n
    y = sprand(k,n,0.2)
    d_y = CudaSparseMatrixCSC(y)
    @test_throws ArgumentError copy!(d_y,d_x)
    d_y = CUSPARSE.switch2csr(d_y)
    d_x = CUSPARSE.switch2csr(d_x)
    @test_throws ArgumentError copy!(d_y,d_x)
    d_y = CUSPARSE.switch2bsr(d_y,convert(Cint,blockdim))
    d_x = CUSPARSE.switch2bsr(d_x,convert(Cint,blockdim))
    @test_throws ArgumentError copy!(d_y,d_x)
end

@testset "char" begin
    @test_throws ArgumentError CUSPARSE.cusparseop('Z')
    @test_throws ArgumentError CUSPARSE.cusparsetype('Z')
    @test_throws ArgumentError CUSPARSE.cusparsefill('Z')
    @test_throws ArgumentError CUSPARSE.cusparsediag('Z')
    @test_throws ArgumentError CUSPARSE.cusparsedir('Z')
    @test_throws ArgumentError CUSPARSE.cusparseindex('A')

    @test CUSPARSE.cusparseop('N') == CUSPARSE.CUSPARSE_OPERATION_NON_TRANSPOSE
    @test CUSPARSE.cusparseop('C') == CUSPARSE.CUSPARSE_OPERATION_CONJUGATE_TRANSPOSE
    @test CUSPARSE.cusparseop('T') == CUSPARSE.CUSPARSE_OPERATION_TRANSPOSE
    @test CUSPARSE.cusparsefill('U') == CUSPARSE.CUSPARSE_FILL_MODE_UPPER
    @test CUSPARSE.cusparsefill('L') == CUSPARSE.CUSPARSE_FILL_MODE_LOWER
    @test CUSPARSE.cusparsediag('U') == CUSPARSE.CUSPARSE_DIAG_TYPE_UNIT
    @test CUSPARSE.cusparsediag('N') == CUSPARSE.CUSPARSE_DIAG_TYPE_NON_UNIT
    @test CUSPARSE.cusparseindex('Z') == CUSPARSE.CUSPARSE_INDEX_BASE_ZERO
    @test CUSPARSE.cusparseindex('O') == CUSPARSE.CUSPARSE_INDEX_BASE_ONE
end

@testset "conversion" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        @testset "make_csc" begin
            x = sparse(rand(elty,m,n))
            d_x = CudaSparseMatrixCSC(x)
            h_x = to_host(d_x)
            @test h_x == x
            @test eltype(d_x) == elty
        end

        @testset "make_csr" begin
            x = sparse(rand(elty,m,n))
            d_x = CudaSparseMatrixCSR(x)
            h_x = to_host(d_x)
            @test h_x == x
        end

        @testset "convert_r2c" begin
            x = sparse(rand(elty,m,n))
            d_x = CudaSparseMatrixCSR(x)
            d_x = CUSPARSE.switch2csc(d_x)
            h_x = to_host(d_x)
            @test h_x.rowval == x.rowval
            @test h_x.nzval ≈ x.nzval
        end

        @testset "convert_r2b" begin
            x = sparse(rand(elty,m,n))
            d_x = CudaSparseMatrixCSR(x)
            d_x = CUSPARSE.switch2bsr(d_x,convert(Cint,blockdim))
            d_x = CUSPARSE.switch2csr(d_x)
            h_x = to_host(d_x)
            @test h_x ≈ x
        end

        @testset "convert_c2b" begin
            x = sparse(rand(elty,m,n))
            d_x = CudaSparseMatrixCSC(x)
            d_x = CUSPARSE.switch2bsr(d_x,convert(Cint,blockdim))
            d_x = CUSPARSE.switch2csc(d_x)
            h_x = to_host(d_x)
            @test h_x ≈ x
        end

        @testset "convert_c2h" begin
            x = sparse(rand(elty,m,n))
            d_x = CudaSparseMatrixCSC(x)
            d_x = CUSPARSE.switch2hyb(d_x)
            d_y = CUSPARSE.switch2csc(d_x)
            CUSPARSE.cusparseDestroyHybMat(d_x.Mat)
            h_x = to_host(d_y)
            @test h_x.rowval == x.rowval
            @test h_x.nzval ≈ x.nzval
        end

        @testset "convert_r2h" begin
            x = sparse(rand(elty,m,n))
            d_x = CudaSparseMatrixCSR(x)
            d_x = CUSPARSE.switch2hyb(d_x)
            d_y = CUSPARSE.switch2csr(d_x)
            CUSPARSE.cusparseDestroyHybMat(d_x.Mat)
            h_x = to_host(d_y)
            @test h_x.rowval == x.rowval
            @test h_x.nzval ≈ x.nzval
        end

        @testset "convert_d2h" begin
            x = rand(elty,m,n)
            d_x = CudaArray(x)
            d_x = CUSPARSE.sparse(d_x,'H')
            d_y = CUSPARSE.full(d_x)
            CUSPARSE.cusparseDestroyHybMat(d_x.Mat)
            h_x = to_host(d_y)
            @test h_x ≈ x
        end

        @testset "convert_d2b" begin
            x = rand(elty,m,n)
            d_x = CudaArray(x)
            d_x = CUSPARSE.sparse(d_x,'B')
            d_y = CUSPARSE.full(d_x)
            h_x = to_host(d_y)
            @test h_x ≈ x
        end

        @testset "convert_c2r" begin
            x = sparse(rand(elty,m,n))
            d_x = CudaSparseMatrixCSC(x)
            d_x = CUSPARSE.switch2csr(d_x)
            h_x = to_host(d_x)
            @test h_x.rowval == x.rowval
            @test h_x.nzval ≈ x.nzval
        end

        @testset "convert_r2d" begin
            x = sparse(rand(elty,m,n))
            d_x = CudaSparseMatrixCSR(x)
            d_x = CUSPARSE.full(d_x)
            h_x = to_host(d_x)
            @test h_x ≈ full(x)
        end

        @testset "convert_c2d" begin
            x = sparse(rand(elty,m,n))
            d_x = CudaSparseMatrixCSC(x)
            d_x = CUSPARSE.full(d_x)
            h_x = to_host(d_x)
            @test h_x ≈ full(x)
        end

        @testset "convert_d2c" begin
            x = rand(elty,m,n)
            d_x = CudaArray(x)
            d_x = CUSPARSE.sparse(d_x,'C')
            h_x = to_host(d_x)
            @test h_x ≈ sparse(x)
        end

        @testset "convert_d2r" begin
            x = rand(elty,m,n)
            d_x = CudaArray(x)
            d_x = CUSPARSE.sparse(d_x)
            h_x = to_host(d_x)
            @test h_x ≈ sparse(x)
        end
    end
end

testnames = ["axpyi","dot","gthr","roti",
             "sctr","bsrsv","hybsv",
             "mv","mm","cssm",
             "bsrsm","gemm","geam","csic",
             "cssv","csilu","bsric",
             "bsrilu","gtsv"]
chosentests = testnames
if( !isempty(ARGS) )
    chosentests = ARGS
end

for test in chosentests
    include("$test.jl")
end
