module JMPReader

export readjmp

using Dates: unix2datetime, Date, DateTime
using DataFrames: DataFrame
using CodecZlib: transcode, GzipDecompressor
using LibDeflate: gzip_decompress!, Decompressor, LibDeflateErrors, LibDeflateErrors.deflate_insufficient_space
using WeakRefStrings: StringVector

include("types.jl")
include("constants.jl")
include("utils.jl")
include("metadata.jl")
include("column.jl")

"""
    function readjmp(fn::AbstractString)

Read a JMP file.
"""
function readjmp(fn::AbstractString)
    isfile(fn) || throw(ArgumentError("\"$fn\" does not exist"))
    a = read(fn)
    check_magic(a, fn)
    info = metadata(a)
    deflatebuffer = Vector{UInt8}()
    alldata = [column_data(a, info, i, deflatebuffer) for i in 1:info.ncols]
    return DataFrame(alldata, info.column.names)
end

end # module JMPReader
