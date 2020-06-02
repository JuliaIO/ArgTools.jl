module ArgTools

export
    arg_read,  ArgRead,  arg_readers,
    arg_write, ArgWrite, arg_writers,
    @arg_test

import Base: AbstractCmd

## main API ##

const ArgRead  = Union{AbstractString, AbstractCmd, IO}
const ArgWrite = Union{AbstractString, AbstractCmd, IO}

arg_read(f::Function, arg::ArgRead) = open(f, arg)
arg_read(f::Function, arg::IO) = f(arg)

function arg_write(f::Function, arg::AbstractString)
    try open(f, arg, write=true)
    catch
        rm(arg, force=true)
        rethrow()
    end
    return arg
end

function arg_write(f::Function, arg::AbstractCmd)
    open(f, arg, write=true)
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

## test utilities ##

macro arg_test(args...)
    arg_test(args...)
end

function arg_test(var::Symbol, args...)
    var = esc(var)
    body = arg_test(args...)
    :($var($var -> $body))
end
arg_test(ex::Expr) = esc(ex)

# core arg_{readers,writers} methods

arg_readers(path::AbstractString) = [
    f -> f(path)
    f -> f(`cat $path`)
    f -> f(pipeline(path, `cat`))
    f -> open(f, path)
    f -> open(f, `cat $path`)
]

arg_writers(path::AbstractString) = [
    f -> f(path)
    f -> f(`tee $path`)
    f -> f(pipeline(`cat`, path))
    f -> open(f, path, write=true)
    f -> open(f, pipeline(`cat`, path), write=true)
]

# higher-order arg_{readers,writers} methods

function arg_readers(body::Function, path::AbstractString)
    foreach(body, arg_readers(path))
end

function arg_writers(body::Function, path::AbstractString)
    foreach(body, arg_writers(path))
end

function arg_writers(body::Function)
    path = tempname()
    map(arg_writers(path)) do writer
        try body(path, writer)
        finally
            rm(path, force=true)
        end
    end
end

end # module
