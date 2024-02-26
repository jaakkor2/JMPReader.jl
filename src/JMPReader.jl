module JMPReader

export readjmp

using Dates: unix2datetime, Date, DateTime
using DataFrames: DataFrame, select!
using CodecZlib: transcode, GzipDecompressor
using LibDeflate: gzip_decompress!, Decompressor, LibDeflateErrors, LibDeflateErrors.deflate_insufficient_space
using WeakRefStrings: StringVector
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

    deflatebuffer = Vector{UInt8}()
    alldata = [column_data(a, info, i, deflatebuffer) for i in colinds]
    names = info.column.names[colinds]
    df = DataFrame(alldata, names)

    return df
end

end # module JMPReader
