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
    lenraw = length(raw)
    lenname = reinterpret(Int16, raw[1:2])[1]
    dtype1 = raw[lenname + 2 .+ (1:2)]
    dtype2 = raw[lenname + 4 .+ (1:2)]
    dtype3 = raw[lenname + 7]

    @debug i, info.column.names[i], dtype1, dtype2, dtype3

    # Float64
    if (dtype1 == [0x01, 0x00] && dtype2 in [[0x0c, 0x63], [0x0c, 0x43], [0x0d, 0x63], [0x0c, 0x03], [0x0c, 0x59], [0x0c, 0x60], [0x0c, 0x42], [0x0d, 0x42], [0x01, 0x00], [0x06, 0x42]]) ||
        (dtype1 == [0x01, 0x01] && dtype2 in [[0x0c, 0x63]]) ||
        (dtype1 == [0x01, 0x02] && dtype2 in [[0x0c, 0x63], [0x09, 0x63]])
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
        dt_floats = _read_reals!(raw, [lenraw-8*info.nrows], Float64, info.nrows)
        out = to_datetime(dt_floats)
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
        dt_floats = _read_reals!(raw, [lenraw-8*info.nrows], Float64, info.nrows)
        out = to_datetime(dt_floats)
        return [ismissing(x) ? missing : x for x in out]
    end

    # Duration
    if dtype1 == [0x01, 0x00] && dtype2 in [[0x0c, 0x85], [0x0e, 0x6c], [0x11, 0x6d], [0x0c, 0x85], [0x0d, 0x84], [0x0c, 0x83]]
        dt_floats = _read_reals!(raw, [lenraw-8*info.nrows], Float64, info.nrows)
        return to_datetime(dt_floats) .- JMP_STARTDATE
    end

    # Character, const width < 8
    if (dtype1 == [0x02, 0x02] && dtype2 in [[0x01, 0x00], [0x02, 0x00], [0x03, 0x00], [0x04, 0x00], [0x06, 0x00]]) ||
        (dtype1 == [0x02, 0x02] && dtype2 == [0x00, 0x00] && dtype3 > 0)
        width = dtype3
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
            error("Unknown `widthbytes=$widthbytes`, some offset is wrong somewhere, column i=$i")
        end
        io = IOBuffer(raw[end-sum(widths)+1:end])
        str = [String(read(io, widths[i])) for i in 1:info.nrows]
        return str
    end

    # Float64, compressed
    if (dtype1 == [0x0a, 0x00] && dtype2 in [[0x0c, 0x63]]) ||
        (dtype1 == [0x0a, 0x02] && dtype2 in [[0x0c, 0x63]])
        idx = findfirst([0x1f, 0x8b], raw)
        isnothing(idx) && error("Compressed stream not found")
        decompressed = transcode(GzipDecompressor, raw[idx[1]:end])
        return reinterpret(Float64, decompressed)
    end

    # Character, compressed, const width < 8
    if dtype1 == [0x09, 0x02] && ((dtype2[2] == 0x00 && 0x01 ≤ dtype2[1] ≤ 0x07) ||
        (dtype2 == [0x00, 0x00] && dtype3 > 0))
        idx = findfirst([0x1f, 0x8b], raw)
        isnothing(idx) && error("Compressed stream not found")
        decompressed = transcode(GzipDecompressor, raw[idx[1]:end])
        width = dtype3
        io = IOBuffer(decompressed)
        str = [String(read(io, width)) for i in 1:info.nrows]
        str = rstrip.(str, '\0')
        str = String.(str) # SubString->String
        return str
    end
    
    # Character, compressed, variable width
    if dtype1 == [0x09, 0x02] && dtype2 == [0x00, 0x00] && dtype3 == 0
        idx = findfirst([0x1f, 0x8b], raw)
        isnothing(idx) && error("Compressed stream not found")
        decompressed = transcode(GzipDecompressor, raw[idx[1]:end])
        lendata = reinterpret(Int64, decompressed[1:8])[1]
        length(decompressed) == lendata + 8 || error("Decompressed length mismatch, i=$i, column=$(info.column.names[i])")
        widthbytes = decompressed[9]
        if widthbytes == 1
            widths = reinterpret(Int8, decompressed[13 .+ (1:info.nrows)])
            io = IOBuffer(decompressed[13 + info.nrows + 1:end])
        elseif widthbytes == 2
            widths = reinterpret(Int16, decompressed[13 .+ (1:2*info.nrows)])
            io = IOBuffer(decompressed[13 + 2*info.nrows + 1:end])
        else
            error("Unknown `widthbytes=$widthbytes`, some offset is wrong somewhere, column i=$i")
        end
        str = [String(read(io, widths[i])) for i in 1:info.nrows]
        return str
    end

    # Time, compressed
    if dtype1 == [0x0a, 0x00] && dtype2 in [[0x17, 0x6a], [0x16, 0x74], [0x16, 0x7e]]
        idx = findfirst(MAGIC_GZIP, raw)
        isnothing(idx) && error("Compressed stream not found")
        decompressed = transcode(GzipDecompressor, raw[idx[1]:end])
        dt_floats = reinterpret(Float64, decompressed)
        out = to_datetime(dt_floats)
        return [ismissing(x) ? missing : x for x in out]
    end

    # Date, compressed
    if dtype1 == [0x0a, 0x00] && dtype2 in [[0x0c, 0x7f]]
        idx = findfirst(MAGIC_GZIP, raw)
        isnothing(idx) && error("Compressed stream not found")
        decompressed = transcode(GzipDecompressor, raw[idx[1]:end])
        dt_floats = reinterpret(Float64, decompressed)
        out = to_datetime(dt_floats)
        return [ismissing(x) ? missing : Date(x) for x in out]
    end

    # Duration, compressed
    if dtype1 == [0x0a, 0x00] && dtype2 in [[0x0c, 0x85]]
        idx = findfirst(MAGIC_GZIP, raw)
        isnothing(idx) && error("Compressed stream not found")
        decompressed = transcode(GzipDecompressor, raw[idx[1]:end])
        dt_floats = reinterpret(Float64, decompressed)
        out = to_datetime(dt_floats) .- JMP_STARTDATE
        return [ismissing(x) ? missing : x for x in out]
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
