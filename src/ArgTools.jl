module ArgTools

export
    arg_read,  ArgRead,
    arg_write, ArgWrite

## main API ##

const ArgRead  = Union{AbstractString, IO}
const ArgWrite = Union{AbstractString, IO}

arg_read(f::Function, arg::AbstractString) = open(f, arg)
arg_read(f::Function, arg::IO) = f(arg)

function arg_write(f::Function, arg::AbstractString)
    try open(f, arg, write=true)
    catch
        rm(arg, force=true)
        rethrow()
    end
    return arg
end

function arg_write(f::Function, arg::Nothing)
    file, io = mktemp()
    try f(io)
    catch
        close(io)
        rm(file, force=true)
        rethrow()
    end
    close(io)
    return file
end

function arg_write(f::Function, arg::IO)
    try f(arg)
    finally
        flush(arg)
    end
    return arg
end

end # module
