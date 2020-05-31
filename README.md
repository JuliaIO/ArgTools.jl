# ArgTools

`ArgTools` provides tools for creating consistent, flexible APIs that work with
various kinds of function arguments. In the current version, it helps deal with
arguments that are, at the core, IO handles, but which you'd like to allow the
user to specify directly as IO handles, as file names, or for arguments that are
written to, not at all, instead writing to a temporary file whose path is
returned. The tests provide a canonical example:

```jl
using ArgTools

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
```

This defines the `send_data` function which reads data from a source and writes
it to a destination, specified by the `src` and `dst` arguments, respectively.
The `src` and `dst` arguments can be any of the constituent types of the union
`ArgRead` and `ArgWrite types, both currently `IO` or `AbstractString`. `IO`
arguments are passed into the inner block as-is, while string arguments are
opened for reading or writing as appropriate. The `dst` argument is optional,
defaulting to `nothing`, in which case `arg_write` will create and open a
temporary file whose IO handle is passed into the inner block and whose path is
returned by `arg_write`. All of this allows the core logic of the `send_data`
function to work only with `IO` handles, `src_io` and `dst_io`, while the API
offers a combinatorial explosion of convenient signatures:

* `send_data(src::AbstractString)`
* `send_data(src::IO)`
* `send_data(src::AbstractString, dst::AbstractString)`
* `send_data(src::IO, dst::AbstractString)`
* `send_data(src::AbstractString, dst::IO)`
* `send_data(src::IO, dst::IO)`

In the future, the plan is to extend `ArgRead` to include `Base.AbstractCmd`,
thereby making it simple to read and write to commands and pipelines as well.
