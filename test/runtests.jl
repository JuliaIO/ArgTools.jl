using Test
using ArgTools

## example test function ##

function send_data(src::ArgRead, dst::Union{ArgWrite, Nothing} = nothing)
    arg_read(src) do src_io
        arg_write(dst) do dst_io
            buffer = Vector{UInt8}(undef, 2*1024*1024)
            while !eof(src_io)
                n = readbytes!(src_io, buffer)
                write(dst_io, view(buffer, 1:n))
            end
        end
    end
end

@testset "main API" begin
    # create a source file
    src_file = tempname()
    data = rand(UInt8, 666)
    write(src_file, data)

    # record what we want to test
    signatures = Set()
    types = [String, Cmd, Base.CmdRedirect, IOStream, Base.Process]
    for S in types
        push!(signatures, Tuple{S})
        for D in types
            push!(signatures, Tuple{S,D})
        end
    end

    arg_readers(src_file) do src
        @arg_test src begin
            pop!(signatures, Tuple{typeof(src)})
            dst_file = send_data(src)
            @test data == read(dst_file)
            rm(dst_file)
        end

        arg_writers() do dst_file, dst
            @test !ispath(dst_file)
            @arg_test src dst begin
                pop!(signatures, Tuple{typeof(src), typeof(dst)})
                @test dst == send_data(src, dst)
            end
            @test data == read(dst_file)
        end

        # also use the method that takes a path
        dst_file = tempname()
        arg_writers(dst_file) do dst
            @test !ispath(dst_file)
            @arg_test src dst begin
                @test dst == send_data(src, dst)
            end
            @test data == read(dst_file)
            rm(dst_file)
        end
    end

    # test that we tested all signatures
    @test isempty(signatures)

    # cleanup
    rm(src_file)
end

## for testing error handling ##

struct ErrIO <: IO end

Base.eof(::ErrIO) = false
Base.write(::ErrIO, ::UInt8) = error("boom")
Base.read(::ErrIO, ::Type{UInt8}) = error("bam")

import Base.Filesystem: TEMP_CLEANUP, temp_cleanup_purge

@testset "error cleanup" begin
    @testset "arg_write(path)" begin
        dst = tempname()
        @test_throws ErrorException send_data(ErrIO(), dst)
        @test !isfile(dst)
    end
    @testset "arg_write(nothing)" begin
        temp_cleanup_purge(false)
        @test length(TEMP_CLEANUP) == 0
        @test_throws ErrorException send_data(ErrIO())
        @test length(TEMP_CLEANUP) == 1
        @test !ispath(first(keys(TEMP_CLEANUP)))
    end
end
