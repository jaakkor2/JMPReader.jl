"""
    JMPReader

Reader for JMP data tables. Exports `readjmp`.
"""
module JMPReader

export readjmp

using Base.Threads: nthreads, @spawn, threadid
using Base.Iterators: partition
using CodecZlib: transcode, GzipDecompressor
using ColorTypes: RGB, FixedPointNumbers.N0f8
using DataFrames: DataFrame, select!, insertcols!
using Dates: unix2datetime, DateTime, Date, Time
using LibDeflate: gzip_decompress!, Decompressor, LibDeflateErrors, LibDeflateErrors.deflate_insufficient_space
using Mmap: mmap
using WeakRefStrings: StringVector
using DeprecateKeywords

include("types.jl")
include("constants.jl")
include("utils.jl")
include("metadata.jl")
include("column.jl")
include("test.jl")

"""
    function readjmp(fn::AbstractString; select::Union{Nothing, Vector} = nothing; drop::Union{Nothing, Vector} = nothing)

Read a JMP file.

Included and excluded columns can be defined using keyword arguments `select` and `drop`.
These are vectors defining columns with any combination of `Integer`, `OrdinalRange`, `String`, `Symbol`, `Regex`.

## Example
```
using JMPReader
fn = joinpath(pathof(JMPReader), "..", "..", "test", "example1.jmp")
df = readjmp(fn)
```
"""
@depkws function readjmp(fn::AbstractString;
    select::Union{Nothing, Vector} = nothing,
    drop::Union{Nothing, Vector} = nothing,
    @deprecate(include_columns, select),
    @deprecate(exclude_columns, drop),
    )
    isfile(fn) || throw(ArgumentError("\"$fn\" does not exist"))
    io = open(fn)
    check_magic(io) || (close(io); throw(ArgumentError("Data table appears to have been corrupted, or `$fn` is not a .jmp file.")))
    info = metadata(io)

    colinds = filter_columns(info.column.names, select, drop)

    close(io)
    
    df = DataFrame()
    lk = ReentrantLock()
    chunk_size = max(1, length(colinds) ÷ Threads.nthreads())
    chunks = Iterators.partition(colinds, chunk_size)
    @sync tasks = map(chunks) do chunk
        Threads.@spawn begin
            deflatebuffer = Vector{UInt8}()
            open(fn) do ios
                for i in chunk
                    data = column_data(ios, info, i, deflatebuffer)
                    lock(lk) do
                        insertcols!(df, info.column.names[i] => data)
                    end
                end
            end
        end
    end
    select!(df, info.column.names[colinds])

    return df
end

end # module JMPReader
