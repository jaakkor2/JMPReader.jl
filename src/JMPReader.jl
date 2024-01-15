module JMPReader

export readjmp

using Dates: unix2datetime, Date, DateTime
using DataFrames: DataFrame

struct Column
    names::Vector{String}
    unknown::Vector{UInt16}
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
    elseif unknown1 == 5
        offset_colinfo += 324 + unknown4
    end
    unknown1 in [3,4,5] || @warn("Never before seen unknown1=$unknown1.  unknown4=$unknown4.")
    
    ncols2 = reinterpret(Int32, a[offset_colinfo .+ (1:4)])[1]
    unknown5 = reinterpret(Int16, a[offset_colinfo + 14 .+ (1:2)])[1]
    
    colidxlist = reinterpret(Int32, a[offset_colinfo + 16 .+ (1:4*ncols)])
    colidxlist == 0:ncols-1 || @warn("`offset_colinfo`-variable probably has a wrong value")
    colformatting = reinterpret(UInt16, a[offset_colinfo + 16 + 4*ncols .+ (1:2*ncols)])
    ###    @show a[offset_colinfo + 16 + 6*ncols+1 : offset_colinfo + 62 + 6*ncols-1]  # possible unknown bytes
    unknowns6 = Int.(a[offset_colinfo + 16 + 6*ncols .+ [31,39,41,43,47]])  # 47 is often equal to ncols, but not always
    @debug unknown1, unknown2, unknown3, unknown4, unknown5, unknowns6
    coldata_offset = offset_colinfo + 16 + 6*ncols

    ncols == ncols2 || @error("Number of columns from two different locations do not match, $ncols vs $ncols2")

    colnames, coloffsets = column_info(a, coldata_offset, ncols)
    
    info = Info(savetime, nrows, ncols, Column(colnames, colformatting, coloffsets))

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
    lenname = raw[1]
    dtype1 = raw[lenname + 2 .+ (1:2)]
    dtype2 = raw[lenname + 4 .+ (1:2)]
    dtype3 = raw[lenname + 7]

    @debug i, info.column.names[i], dtype1, dtype2, dtype3

    # Float64
    if (dtype1 == [0x01, 0x00] && dtype2 in [[0x0c, 0x63], [0x0c, 0x43], [0x0d, 0x63], [0x0c, 0x03], [0x0c, 0x59], [0x0c, 0x60], [0x0c, 0x42], [0x0d, 0x42], [0x01, 0x00], [0x06, 0x42]]) ||
        (dtype1 == [0x01, 0x01] && dtype2 in [[0x0c, 0x63]]) ||
        (dtype1 == [0x01, 0x02] && dtype2 in [[0x0c, 0x63]])
        out = reinterpret(Float64, raw[end-8*info.nrows+1:end])
        out = replace(out, NaN => missing)
        return out
    end

    # Date
    if (dtype1 == [0x01, 0x00] && dtype2 in [
        [0x0c, 0x65], [0x0c, 0x6e], [0x0c, 0x6f], [0x0c, 0x70], [0x0c, 0x71], [0x0c, 0x72], [0x0c, 0x75], [0x0c, 0x76],
        [0x0c, 0x7a], [0x0c, 0x7f],
        [0x0c, 0x88], [0x0c, 0x8b],
        [0x0a, 0x70], [0x0a, 0x75],
        [0x14, 0x67], [0x23, 0x66],
        ]) ||
        (dtype1 == [0x01, 0x02] && dtype2 == [0x0c, 0x7f])
        out = to_datetime(raw[end-8*info.nrows+1:end])
        return [ismissing(x) ? missing : Date(x) for x in out]
    end

    # Time
    if dtype1 == [0x01, 0x00] && dtype2 in [
        [0x16, 0x7e], [0x16, 0x74], [0x13, 0x7d],
        [0x13, 0x69], [0x17, 0x6a], [0x16, 0x73],
        [0x13, 0x77], [0x16, 0x78], [0x13, 0x86],
        [0x13, 0x87], [0x13, 0x7b], [0x16, 0x7c],
        [0x13, 0x6c], [0x13, 0x6d], [0x13, 0x79],
        [0x13, 0x82], [0x13, 0x80], [0x13, 0x81],
        [0x13, 0x89], [0x17, 0x8a]
        ]
        return to_datetime(raw[end-8*info.nrows+1:end])
    end

    # Duration
    if dtype1 == [0x01, 0x00] && dtype2 in [[0x0c, 0x85], [0x0e, 0x6c], [0x11, 0x6d], [0x0c, 0x85], [0x0d, 0x84], [0x0c, 0x83]]
        return to_datetime(raw[end-8*info.nrows+1:end]) .- DateTime(1904,1,1,0,0,0)
    end

    # Character, const width < 8
    if (dtype1 == [0x02, 0x02] && dtype2 in [[0x01, 0x00], [0x04, 0x00], [0x06, 0x00], [0x02, 0x00]]) ||
        (dtype1 == [0x02, 0x02] && dtype2 == [0x00, 0x00] && dtype3 > 0)
        width = raw[lenname + 7]
        io = IOBuffer(raw[end-info.nrows*width+1:end])
        str = [String(read(io, width)) for i in 1:info.nrows]
        str = rstrip.(str, '\0')
        str = String.(str) # SubString->String
        return str
    end

    # Character, variable width
    if dtype1 == [0x02, 0x02] && dtype2 == [0x00, 0x00] && dtype3 == 0
        hasunits = raw[lenname + 13] # used
        unknown1 = raw[lenname + 15] # not used, a bit similar to offset3
        unknown2 = raw[lenname + 23] # not used
        offset1 = raw[lenname + 25]  # used
        lenunits = raw[lenname + 33]
        ofs = lenname + offset1 # offset to width data
        if hasunits == 1
            offset2 = raw[lenname + lenunits + 43]
            ofs += offset2 + 10
        end
        widthbytes = raw[ofs + 37]
        if widthbytes == 0x01 # Int8
            widths = reinterpret(Int8, raw[ofs + 41 .+ (1:info.nrows)])
        elseif widthbytes == 0x02 # Int16
            widths = reinterpret(Int16, raw[ofs + 41 .+ (1:2*info.nrows)])
        else
            error("Unknown `widthbytes=$widthbytes`, some offset is wrong somewhere")
        end
        io = IOBuffer(raw[end-sum(widths)+1:end])
        str = [String(read(io, widths[i])) for i in 1:info.nrows]
        return str
    end
    
    @error("Data type combination `dtype1,dtype2,dtype3=$dtype1,$dtype2,$dtype3` not implemented, found in column `$(info.column.names[i])` (i=$i), returning raw data for debugging")
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
