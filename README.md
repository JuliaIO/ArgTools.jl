# ArgTools

[![Build Status](https://travis-ci.org/JuliaIO/ArgTools.jl.svg?branch=master)](https://travis-ci.org/JuliaIO/ArgTools.jl)
[![Codecov](https://codecov.io/gh/JuliaIO/ArgTools.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/JuliaIO/ArgTools.jl)

`ArgTools` provides tools for creating consistent, flexible APIs that work with
various kinds of function arguments. In the current version, it helps deal with
arguments that are, at their core, IO handles, but which you'd like to allow the
user to specify directly as file names, commands, pipelines, or, of course, as
raw IO handles. For write arguments, it's also possible to use `nothing` and
write to a temporary file whose path is returned.

## API

There are two parts to the `ArgTools` API:

1. Functions and types for helping define flexible function APIs.
2. Functions for helping to test APIs defined with above.

While it's great to be able to define a flexible API, if you're not sure that
it works the way it's supposed to, what's the benefit. Since it's can be quite
verbose to test such a combinatorial explosion of methods, `ArgTools` also
provides tools to help testing all the ways your tools can be called to make
sure everything is working as intended.

### Argument Handling

The API for helping defining flexible function signatures consists of two types
and four helper functions: `ArgRead` and `ArgWrite`; `arg_read`, `arg_write`,
`arg_isdir` and `arg_mkdir`.

<!-- BEGIN: copied from inline doc strings -->

#### ArgRead

```jl
ArgRead = Union{AbstractString, AbstractCmd, IO}
```
The `ArgRead` types is a union of the types that the `arg_read` function knows
how to convert into readable IO handles. See [`arg_read`](@ref) for details.

#### ArgWrite

```jl
ArgWrite = Union{AbstractString, AbstractCmd, IO}
```
The `ArgWrite` types is a union of the types that the `arg_write` function knows
how to convert into writeable IO handles, except for `Nothing` which `arg_write`
handles by generating a temporary file. See [`arg_write`](@ref) for details.

#### arg_read

```jl
arg_read(f::Function, arg::ArgRead) -> f(arg_io)
```
The `arg_read` function accepts an argument `arg` that can be any of these:

- `AbstractString`: a file path to be opened for reading
- `AbstractCmd`: a command to be run, reading from its standard output
- `IO`: an open IO handle to be read from

Whether the body returns normally or throws an error, a path which is opened
will be closed before returning from `arg_read` and an `IO` handle will be
flushed but not closed before returning from `arg_read`.

#### arg_write

```jl
arg_write(f::Function, arg::ArgWrite) -> arg
arg_write(f::Function, arg::Nothing) -> tempname()
```
The `arg_write` function accepts an argument `arg` that can be any of these:

- `AbstractString`: a file path to be opened for writing
- `AbstractCmd`: a command to be run, writing to its standard input
- `IO`: an open IO handle to be written to
- `Nothing`: a temporary path should be written to

If the body returns normally, a path that is opened will be closed upon
completion; an IO handle argument is left open but flushed before return. If the
argument is `nothing` then a temporary path is opened for writing and closed
open completion and the path is returned from `arg_write`. In all other cases,
`arg` itself is returned. This is a useful pattern since you can consistently
return whatever was written, whether an argument was passed or not.

If there is an error during the evaluation of the body, a path that is opened by
`arg_write` for writing will be deleted, whether it's passed in as a string or a
temporary path generated when `arg` is `nothing`.

#### arg_isdir

```jl
arg_isdir(f::Function, arg::AbstractString) -> f(arg)
```
The `arg_isdir` function takes `arg` which must be the path to an existing
directory (an error is raised otherwise) and passes that path to `f` finally
returning the result of `f(arg)`. This is definitely the least useful tool
offered by `ArgTools` and mostly exists for symmetry with `arg_mkdir` and to
give consistent error messages.

#### arg_mkdir

```jl
arg_mkdir(f::Function, arg::AbstractString) -> arg
arg_mkdir(f::Function, arg::Nothing) -> mktempdir()
```
The `arg_mkdir` function takes `arg` which must either be one of:

- a path to an already existing empty directory,
- a non-existent path which can be created as a directory, or
- `nothing` in which case a temporary directory is created.

In all cases the path to the directory is returned. If an error occurs during
`f(arg)`, the directory is returned to its original state: if it already existed
but was empty, it will be emptied; if it did not exist it will be deleted.

<!-- END: copied from inline doc strings -->

### Function Testing

Using `ArgTools` is easy; thoroughly testing flexible functions defined using
`ArgTools` is a bit trickier, but the package includes testing tools that help.
The API for testing functions defined with the argument handling API consists
of two functions and a macro: `arg_readers`, `arg_writers` and `@arg_test`.

<!-- BEGIN: copied from inline doc strings -->

#### arg_readers

```jl
arg_readers(arg :: AbstractString, [ type = ArgRead ]) do arg::Function
    ## pre-test setup ##
    @arg_test arg begin
        arg :: ArgRead
        ## test using `arg` ##
    end
    ## post-test cleanup ##
end
```

The `arg_readers` function takes a path to be read and a single-argument do
block, which is invoked once for each test reader type that `arg_read` can
handle. If the optional `type` argument is given then the do block is only
invoked for readers that produce arguments of that type.

The `arg` passed to the do block is not the argument value itself, because some
of test argument types need to be initialized and finalized for each test case.
Consider an open file handle argument: once you've used it for one test, you
can't use it again; you need to close it and open the file again for the next
test. This function `arg` can be converted into an `ArgRead` instance using
`@arg_test arg begin ... end`.

#### arg_writers

```jl
arg_writers([ type = ArgWrite ]) do path::String, arg::Function
    ## pre-test setup ##
    @arg_test arg begin
        arg :: ArgWrite
        ## test using `arg` ##
    end
    ## post-test cleanup ##
end
```

The `arg_writers` function takes a do block, which is invoked once for each test
writer type that `arg_write` can handle with a temporary (non-existent) `path`
and `arg` which can be converted into various writable argument types which
write to `path`. If the optional `type` argument is given then the do block is
only invoked for writers that produce arguments of that type.

The `arg` passed to the do block is not the argument value itself, because some
of test argument types need to be initialized and finalized for each test case.
Consider an open file handle argument: once you've used it for one test, you
can't use it again; you need to close it and open the file again for the next
test. This function `arg` can be converted into an `ArgWrite` instance using
`@arg_test arg begin ... end`.

There is also an `arg_writers` method that takes a path name like `arg_readers`:

```jl
arg_writers(path::AbstractString, [ type = ArgWrite ]) do arg::Function
    ## pre-test setup ##
    @arg_test arg begin
        arg :: ArgWrite
        ## test using `arg` ##
    end
    ## post-test cleanup ##
end
```

This method is useful if you need to specify `path` instead of using path name
generated by `tempname()`. Since `path` is passed from outside of `arg_writers`,
the path is not an argument to the do block in this form.

#### @arg_test

```jl
@arg_test arg1 arg2 ... body
```

The `@arg_test` macro is used to convert `arg` functions provided by
`arg_readers` and `arg_writers` into actual argument values. When you write
`@arg_test arg body` it is equivalent to `arg(arg -> body)`.

<!-- END: copied from inline doc strings -->

## Examples

The examples, like the API, are split into two parts:

1. An example of defining a function with a flexible API using the main API;
2. Examples of how to thoroughly test that function using the test utilities.

### Usage Example

The best explanation may be an example, which is also used for testing:

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
Thanks to `ArgTools`, this relatively simple definition acts as a swiss-army
knife for sending data from a source to a destination. Here are some examples:

```jl
julia> cd(mktempdir())

julia> write("hello.txt", "Hello, world.\n")
14

julia> run(`cat hello.txt`);
Hello, world.

julia> send_data("hello.txt", "hello_copy.txt")
"hello_copy.txt"

julia> run(`cat $ans`);
Hello, world.

julia> rm("hello_copy.txt")

julia> send_data("hello.txt", stdout);
Hello, world.

julia> send_data("hello.txt", pipeline(`gzip -9`, "hello.gz"));

julia> run(`gzcat hello.gz`);
Hello, world.

julia> hello_copy = send_data(`gzcat hello.gz`)
"/var/folders/4g/b8p546px3nd550b3k288mhp80000gp/T/jl_cguepi"

julia> run(`cat $hello_copy`);
Hello, world.
```

To understand the definition of `send_data`, let's work from the inside out:

* The main body of the function operates on the `src_io` and `dst_io` IO
  handles, using a buffer to read data from the former to the latter in 2MiB
  blocks.

* The calls to `arg_read` and `arg_write` transform the `src` and `dst`
  arguments from various types to `src_io` and `dst_io` IO handles. This allows
  the inner body to handle the core case of dealing with IO handles, without
  having to worry about the various possible incoming argument types. See the API
  section below for more details about how `arg_read` and `arg_write` work on
  different types.

* The arguments to `send_data` are `src::ArgRead` and `dst::ArgWrite` where
  `dst` is optional and defaults to `nothing` if not given. The `ArgRead` type is
  a union including all the types that `arg_read` knows how to handle. Similarly,
  the `ArgWrite` type is a union including the types that `arg_write` knows how to
  handle, except for `nothing` which must be explicitly opted into, for which
  `arg_write` creates a temporary file and returns its path.

Taken altogether, this allows the `send_data` function to work with a combinatorial
explosion of type signatures:

* `send_data(src::AbstractString)`
* `send_data(src::AbstractCmd)`
* `send_data(src::IO)`
* `send_data(src::AbstractString, dst::AbstractString)`
* `send_data(src::AbstractCmd,    dst::AbstractString)`
* `send_data(src::IO,             dst::AbstractString)`
* `send_data(src::AbstractString, dst::AbstractCmd)`
* `send_data(src::AbstractCmd,    dst::AbstractCmd)`
* `send_data(src::IO,             dst::AbstractCmd)`
* `send_data(src::AbstractString, dst::IO)`
* `send_data(src::AbstractCmd,    dst::IO)`
* `send_data(src::IO,             dst::IO)`

Each combination guarantees the proper initialization and cleanup of its
arguments whether it is opening a file and closing it upon completion or error,
or creating a temporary output file and returning it upon completion or deleting
it on error. If the arguments are commands or pipelines, those are correctly
opened with the necessary read/write options.

### Testing Example

Now that we've defined the `send_data` function, we must test it. But it has so
many different kinds of arguments that it can accept, how do we produce tests
for all of these combinations? `ArgTools` also offers tools to help with testing
APIs that it lets you define. The example tests assume that the above definition
of `send_data` has already been evaluated in the same Julia session.

```jl
using Test

# create a source file
src_file = tempname()
data = rand(UInt8, 666)
write(src_file, data)

print_sig(args...) =
    println("send_data(", join(map(typeof, args), ", "), ")")

arg_readers(src_file) do src
    # test 1-arg methods
    @arg_test src begin
        print_sig(src)
        dst_file = send_data(src)
        @test data == read(dst_file)
        rm(dst_file)
    end

    # test 2-arg methods
    arg_writers() do dst_file, dst
        @arg_test src dst begin
            print_sig(src, dst)
            @test dst == send_data(src, dst)
        end
        @test data == read(dst_file)
    end
end

# cleanup
rm(src_file)
```

Evaluating this testing code prints the following output:
```jl
send_data(String)
send_data(String, String)
send_data(String, Cmd)
send_data(String, Base.CmdRedirect)
send_data(String, IOStream)
send_data(String, Base.Process)
send_data(Cmd)
send_data(Cmd, String)
send_data(Cmd, Cmd)
send_data(Cmd, Base.CmdRedirect)
send_data(Cmd, IOStream)
send_data(Cmd, Base.Process)
send_data(Base.CmdRedirect)
send_data(Base.CmdRedirect, String)
send_data(Base.CmdRedirect, Cmd)
send_data(Base.CmdRedirect, Base.CmdRedirect)
send_data(Base.CmdRedirect, IOStream)
send_data(Base.CmdRedirect, Base.Process)
send_data(IOStream)
send_data(IOStream, String)
send_data(IOStream, Cmd)
send_data(IOStream, Base.CmdRedirect)
send_data(IOStream, IOStream)
send_data(IOStream, Base.Process)
send_data(Base.Process)
send_data(Base.Process, String)
send_data(Base.Process, Cmd)
send_data(Base.Process, Base.CmdRedirect)
send_data(Base.Process, IOStream)
send_data(Base.Process, Base.Process)
```

Test code doesn't isn't normally this verbose, but for this example it may be
helpful to understand what's happening. What this output shows is the various
ways in which this short bit of code tests invoking the `send_data` function.
Here are some details about what's happening:

* The call to `arg_readers(src_file)` evaluates the attached do block with five
  different `arg` values, which can be converted to readable arguments of the
  types: `String`, `Cmd`, `CmdRedirect`, `IOStream` and `Process`.

* The call to `@arg_test src begin ... end` converts `src` into a readable
  arguments of those same types and closes or finalizes each at the end.

* The call to `arg_writers()` evaluates the attached do block with five
  different `arg` values, which can be converted to writable arguments of the
  types: `String`, `Cmd`, `CmdRedirect`, `IOStream` and `Process`.

* The call to `@arg_test src dst begin ... end` converts `src` into a readable
  arguments and `dst` into writeable arguments of the same set of types, and
  closes or otherwise finalizes each one at the end of the block.

This example test code illustrates some of the reasoning features of the testing
API which might initially seem puzzling. For example, it shows why `arg_readers`
and `arg_writers` don't simply produce argument values that can be passed to the
function being tested, instead requiring conversion by the `@arg_test` macro.
There are two reasons:

1. The same value returned from `arg_readers` or `arg_writers` may need to be
   used in multiple tests and some argument types, such as IO handles, need to
   be initialized before each test and finalized after. The `@arg_test` block
   delimits where initialization and finalization occur.

2. Sometimes operations need to be done after the `@arg_test` block but before
   the end of the enclosing `arg_readers` or `arg_writers` block. Testing that
   `dst_file` has the expected contents, i.e. `@test data == read(dst_file)`,
   will not work reliably inside of the `@arg_test` block: data is not guaranteed
   to have been fully written to `dst_file` until `dst` is finalized. This is an
   issue when `dst` is an already-opened process, for example: `arg_write` leaves
   the process open since it received it that way (you might want to write more
   data to it), and while it does flush the handle, there is no guarantee that
   the process will get data to its final destination until the process has
   exited. Putting the test after the `@arg_test` block ensures that the process
   has terminated, so we can reliably test the contents of `dst_file`.
