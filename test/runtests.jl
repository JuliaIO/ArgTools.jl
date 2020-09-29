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

@testset "arg_{read,write}" begin
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

import Base.Filesystem: TEMP_CLEANUP

@testset "error cleanup" begin
    @testset "arg_write(path)" begin
        dst = tempname()
        @test_throws ErrorException send_data(ErrIO(), dst)
        @test !isfile(dst)
    end
    @testset "arg_write(nothing)" begin
        SAVE_TEMP_CLEANUP = copy(TEMP_CLEANUP)
        empty!(TEMP_CLEANUP)
        try
            @test_throws ErrorException send_data(ErrIO())
            @test length(TEMP_CLEANUP) == 1
            @test !ispath(first(keys(TEMP_CLEANUP)))
        finally
            merge!(TEMP_CLEANUP, SAVE_TEMP_CLEANUP)
        end
    end
end

# broken on Julia CI when testing as a stdlib on Windows
const chmod_0o000 = !Sys.iswindows() || Main == @__MODULE__

@testset "arg_{is,mk}dir" begin
    @testset "arg_isdir" begin
        dir = tempname()
        @test_throws ErrorException arg_isdir(identity, dir)
        mkdir(dir)
        @test "%$dir%" == arg_isdir(d -> "%$d%", dir)
        rm(dir)
    end

    @testset "arg_mkdir" begin
        dir = tempname()
        # creates a non-existent directory
        @test dir == arg_mkdir(d -> "%$d%", dir)
        @test isdir(dir)
        # accepts a pre-existing empty directory
        @test dir == arg_mkdir(d -> "%$d%", dir)
        @test isdir(dir)
        # refuses a non-empty directory
        touch(joinpath(dir, "file"))
        @test_throws ErrorException arg_mkdir(identity, dir)
        rm(dir, recursive=true)
        # refuses a non-directory
        file = tempname()
        touch(file)
        @test_throws ErrorException arg_mkdir(identity, file)
        rm(file)
        # creates a temporary directory
        dir = arg_mkdir(d -> "%$d%", nothing)
        @test isdir(dir)
        rm(dir)
        # on error, restores (deletes) a non-existent directory
        tmp = tempname()
        @test_throws ErrorException arg_mkdir(tmp) do dir
            @test dir == tmp
            file = joinpath(dir, "file")
            touch(file)
            chmod_0o000 &&
            chmod(file, 0o000)
            error("boof")
        end
        @test !ispath(tmp)
        # on error, restores (empties) an empty directory
        tmp = mktempdir()
        chmod(tmp, 0o741)
        st = stat(tmp)
        file = joinpath(tmp, "file")
        @test_throws ErrorException arg_mkdir(tmp) do dir
            @test dir == tmp
            touch(file)
            chmod_0o000 &&
            chmod(file, 0o000)
            error("blammo")
        end
        @test !ispath(file)
        @test isdir(tmp)
        @test isempty(readdir(tmp))
        @test filemode(tmp) == filemode(st)
        @test Base.Filesystem.samefile(st, stat(tmp))
        rm(tmp)
    end
end
