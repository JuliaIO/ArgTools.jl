using ArgTools
using Test

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

@testset "ArgTools.jl" begin
    # create a source file
    src = tempname()
    data = rand(UInt8, 666)
    write(src, data)

    # test send_data(src::String)
    dst = send_data(src)
    @test data == read(dst)
    rm(dst)

    # test send_data(src::IO)
    dst = open(send_data, src)
    @test data == read(dst)
    rm(dst)

    # test send_data(src::String, dst::String)
    dst = tempname()
    @test dst == send_data(src, dst)
    @test data == read(dst)
    rm(dst)

    # test send_data(src::IO, dst::String)
    dst = tempname()
    @test dst == open(src) do src
        send_data(src, dst)
    end
    @test data == read(dst)
    rm(dst)

    # test send_data(src::String, dst::IO)
    dst = tempname()
    open(dst, write=true) do dst
        send_data(src, dst)
    end
    @test data == read(dst)
    rm(dst)

    # test send_data(src::IO, dst::IO)
    dst = tempname()
    open(src) do src
        open(dst, write=true) do dst
            send_data(src, dst)
        end
    end
    @test data == read(dst)
    rm(dst)

    # cleanup
    rm(src)
end
