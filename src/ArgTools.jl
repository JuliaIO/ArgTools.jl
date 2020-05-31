module ArgTools

export
    arg_read, ArgRead,
    arg_write, ArgWrite

const ArgRead  = Union{AbstractString, IO}
const ArgWrite = Union{AbstractString, IO}

arg_read(f::Function, file::AbstractString) = open(f, file)
arg_read(f::Function, file::IO) = f(file)

function arg_write(f::Function, file::AbstractString)
    try open(f, file, write=true)
    catch
        rm(file, force=true)
        rethrow()
    end
    return file
end

function arg_write(f::Function, file::Nothing)
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

function arg_write(f::Function, file::IO)
    try f(file)
    finally
        flush(file)
    end
    return file
end

end # module
