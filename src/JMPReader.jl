module JMPReader

export readjmp

using Dates: unix2datetime, Date, DateTime
using DataFrames: DataFrame

struct Column
    names::Vector{String}
    datatypes::Vector{Int16}
    offsets::Vector{Int64}
end

struct Info
    savetime::DateTime
    nrows::Int
    ncols::Int
    column::Column
end



"""
    function readjmp(fn::AbstractString)

Read a JMP file.
"""
function readjmp(fn::AbstractString)
    isfile(fn) || (@error("File `$fn` does not exist`"); return nothing)
    a = read(fn)
    len = length(a)
    len < 507 && (@error("File `$fn` length=$len.  Maybe truncated?"); return nothing)
    nrows = reinterpret(Int64, a[368 .+ (1:8)])[1]
    ncols = reinterpret(Int32, a[376 .+ (1:4)])[1]
    savetime = to_datetime(a[407:414])[1]
    unknown1 = reinterpret(Int16, a[482:483])[1]  ## unknown parameter causing different offsets in columns data
    unknown2 = reinterpret(Int32, a[484:487])[1]
    unknown3 = reinterpret(Int16, a[492:493])[1]
    unknown4 = reinterpret(Int16, a[494:495])[1]  ## unknown parameter causing different offsets in columns data
    offset_colinfo = 503
    if unknown1 == 4
        offset_colinfo += 10 + unknown4
    end
    unknown1 in [3,4] || @warn("Never before seen unknown1=$unknown1")
    
    ncols2 = reinterpret(Int32, a[offset_colinfo .+ (1:4)])[1]
    unknown5 = reinterpret(Int16, a[offset_colinfo + 14 .+ (1:2)])[1]
    
    colidxlist = reinterpret(Int32, a[offset_colinfo + 16 .+ (1:4*ncols)])
    colidxlist == 0:ncols-1 || @warn("`offset_colinfo`-variable probably has a wrong value")
    coltypes = reinterpret(Int16, a[offset_colinfo + 16 + 4*ncols .+ (1:2*ncols)])
    ###    @show a[offset_colinfo + 16 + 6*ncols+1 : offset_colinfo + 62 + 6*ncols-1]  # possible unknown bytes
    unknowns6 = Int.(a[offset_colinfo + 16 + 6*ncols .+ [31,39,41,43,47]])  # 47 is often equal to ncols, but not always
    @show unknown1, unknown2, unknown3, unknown4, unknown5, unknowns6
    coldata_offset = offset_colinfo + 16 + 6*ncols # 1-9

    ncols == ncols2 || @error("Number of columns from two different locations do not match, $ncols vs $ncols2")

    colnames, coloffsets = column_info(a, coldata_offset, ncols)
    
    info = Info(savetime, nrows, ncols, Column(colnames, coltypes, coloffsets))
    alldata = [column_data(a, info, i) for i in 1:info.ncols]
    return DataFrame(alldata, info.column.names)
end

function column_rawdata(data, info, i::Int)
    1 ≤ i ≤ info.ncols || error("requested column $i is out-of-bounds")
    i == info.ncols && return data[info.column.offsets[i]+1:end]
    return data[info.column.offsets[i]+1:info.column.offsets[i+1]]
end

"""
    column_data(data, info, i::Int)

Return data from `i`th column.
"""
function column_data(data, info, i::Int)
    1 ≤ i ≤ info.ncols || error("requested column $i is out-of-bounds")
    raw = column_rawdata(data, info, i)
    dtype = info.column.datatypes[i]

    # Float64
    if dtype in [38,49,53,60,62,67,78,155]
        out = reinterpret(Float64, raw[end-8*info.nrows+1:end])
        out = replace(out, NaN => missing)
        return out
    end

    # Date
    if dtype in [61]
        out = to_datetime(raw[end-8*info.nrows+1:end])
        return [ismissing(x) ? missing : Date(x) for x in out]
    end

    # Time
    if dtype in [102,108]
        return to_datetime(raw[end-8*info.nrows+1:end])
    end

    # Duration
    if dtype in [73]
        return to_datetime(raw[end-8*info.nrows+1:end]) .- DateTime(1904,1,1,0,0,0)
    end

    # Character, const width < 127
    # 44 is formula, now return the strings
    if dtype in [54,93,123,169,44]
        width = raw[raw[1] + 7]
        io = IOBuffer(raw[end-info.nrows*width+1:end])
        str = [String(read(io, width)) for i in 1:info.nrows]
        str = rstrip.(str, '\0')
        str = String.(str) # SubString->String
        return str
    end

    # Character, variable width
    if dtype in [50,76,169,360]
        ofs = raw[1] + raw[raw[1]+25] # offset to width data
        if dtype in [50,76,169] # Int8
            widths = reinterpret(Int8, raw[ofs + 41 .+ (1:info.nrows)])
        else # Int16
            widths = reinterpret(Int16, raw[ofs + 41 .+ (1:2*info.nrows)])
        end
        io = IOBuffer(raw[end-sum(widths)+1:end])
        str = [String(read(io, widths[i])) for i in 1:info.nrows]
        return str
    end
    
    @error("Data type $dtype not implemented of column $(info.column.names[i]) (i=$i), returning raw data")
    return raw
end

function column_data(data, info, name::Union{String,Regex})
    name in info.column.names || error("Column name $name does not exist")
    if isa(name, String)
        fun = isequal(name)
    else
        fun = x -> !isnothing(match(name, x))
    end
    idx = findall(fun, info.column.names)
    columns = [column_data(data, info, i) for i in idx]
    names = info.column.names[idx]
    return DataFrame(columns, names)
end


"""
    column_info(data, offset, ncols)

Return column names and offsets to column data.
"""
function column_info(data, offset, ncols)
    hacky_offset = data[offset + 31] + 42
    coloffsets = reinterpret(Int64, data[offset + hacky_offset .+ (1:8*ncols)])
    colnames = String[]
    for i in coloffsets
        width = data[1+i]
        data[2+i] == 0 || @info("Byte with previously unseen content $(data[2+i]) at $(2+i)")
        push!(colnames, String(data[2+i .+ (1:width)]))
    end
    return colnames, coloffsets
end

"""
    to_datetime(a::Vector{UInt8})

Convert a 8-multiple vector of `UInt8`s to vector of `DateTime`s.
JMP uses the 1904 date system, correct for that.
"""
function to_datetime(a::Vector{UInt8})
    mod(length(a), 8) == 0 || error("Length should be a multiple of 8")
    floats = reinterpret(Float64, a)
    dt = [isnan(float) ? missing : unix2datetime(float) for float in floats]
    dt .- (Date(1970, 1, 1) - Date(1904, 1, 1))
end

end # module JMPReader
