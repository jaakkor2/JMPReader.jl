module JMPReader

export readjmp

using Dates: unix2datetime, Date, DateTime
using DataFrames: DataFrame, select!, insertcols!
using CodecZlib: transcode, GzipDecompressor
using LibDeflate: gzip_decompress!, Decompressor, LibDeflateErrors, LibDeflateErrors.deflate_insufficient_space
using WeakRefStrings: StringVector
using Base.Threads: nthreads, @spawn, threadid
using Base.Iterators: partition

include("types.jl")
include("constants.jl")
include("utils.jl")
include("metadata.jl")
include("column.jl")

"""
    function readjmp(fn::AbstractString; include_columns::Union{Nothing, Vector} = nothing; exclude_columns::Union{Nothing, Vector} = nothing)

Read a JMP file.

Included and excluded columns can be defined using keyword arguments `include_columns` and `exclude_columns`.
These are vectors defining columns with any combination of `Integer`, `OrdinalRange`, `String`, `Symbol`, `Regex`.
"""
function readjmp(fn::AbstractString;
    include_columns::Union{Nothing, Vector} = nothing,
    exclude_columns::Union{Nothing, Vector} = nothing)

    isfile(fn) || throw(ArgumentError("\"$fn\" does not exist"))
    a = read(fn)
    check_magic(a, fn)
    info = metadata(a)
    colinds = filter_columns(info.column.names, include_columns, exclude_columns)

    df = DataFrame()
    deflatebuffers = [Vector{UInt8}() for i = 1:Threads.nthreads()]
    lk = ReentrantLock()
    Threads.@threads :static for i in colinds
        data = column_data(a, info, i, deflatebuffers[threadid()])
        lock(lk) do
            insertcols!(df, info.column.names[i] => data)
        end
    end
    select!(df, info.column.names[colinds])

    return df
end

end # module JMPReader
