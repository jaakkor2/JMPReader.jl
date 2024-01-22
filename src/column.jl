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

    offset = [0]
    columnname = _read_string!(raw, offset, 2)
    lenname = length(columnname)
    dt1, dt2, dt3, dt4, dt5 = _read_reals!(raw, offset, UInt8, 5)

    # compressed
    if dt1 in [0x09, 0x0a]
        idx = findfirst(MAGIC_GZIP, raw)
        isnothing(idx) && throw(ExceptionError("Compressed stream not found"))
        a = transcode(GzipDecompressor, raw[idx[1]:end])
    else
        a = raw
    end
    
    # one of Float64, Date, Time, Duration
    # dt3 = format width
    if dt1 in [0x01, 0x0a]
        out = reinterpret(Float64, a[end-8*info.nrows+1:end])
        # Float64
        if  (dt4 == dt5 && dt4 in [
            0x00, 0x03, 0x42, 0x43, 0x59, 0x60, 0x63,
            ]) ||
            dt5 in [0x5e] # fixed dec, dt3=width, dt4=dec

            out = replace(out, NaN => missing)
            return out
        end
        # then it is a date, time or duration
        out = to_datetime(out)
        # Date
        if (dt4 == dt5 && dt4 in [
            0x65, 0x66, 0x67, 0x6e, 0x6f, 0x70, 0x71, 0x72, 0x75, 0x76, 0x7a,
            0x7f, 0x88, 0x8b,
            ]) ||
            [dt4, dt5] in [[0x72, 0x65]]

            return [ismissing(x) ? missing : Date(x) for x in out]
        end
        # Time
        if dt5 in [0x69, 0x6a, 0x73, 0x74, 0x78, 0x7e, 0x81] && dt4 in [
            0x69, 0x6a, 0x6c, 0x6d, 0x73, 0x74, 0x77, 0x78, 0x79, 0x7b, 0x7c,
            0x7d, 0x7e, 0x80, 0x81, 0x82, 0x86, 0x87, 0x89, 0x8a,
            ]
            return [ismissing(x) ? missing : DateTime(x) for x in out]

        end
        # Duration
        if dt4 == dt5 && dt4 in [
            0x0c, 0x6b, 0x6c, 0x6d, 0x83, 0x84, 0x85
            ]
            return [ismissing(x) ? missing : DateTime(x) - JMP_STARTDATE for x in out]
        end
        # Currency
        if dt4 == dt5 && dt4 in [0x5f]
            # 1,0,13,95,95
            @warn("currency not implemented")
        end
    end
    # 1-byte integer
    if dt1 == 0xff # custom format?
        # 255,0,4,99,1
        @warn("one-byte integer not implemented")
    end

    # character
    if dt1 in [0x02, 0x09]
        # constant width
        if ([dt3, dt4] == [0x00, 0x00] && dt5 > 0) ||
            (0x01 ≤ dt3 ≤ 0x07 && dt4 == 0x00)
            width = dt5
            io = IOBuffer(a[end-info.nrows*width+1:end])
            str = [String(read(io, width)) for i in 1:info.nrows]
            str = rstrip.(str, '\0')
            str = String.(str) # SubString->String
            return str
        end
        
        # variable width
        if [dt3, dt4, dt5] == [0x00, 0x00, 0x00]
            if dt1 == 0x09 # compressed
                widthbytes = a[9]
                if widthbytes == 1
                    widths = reinterpret(Int8, a[13 .+ (1:info.nrows)])
                    io = IOBuffer(a[13 + info.nrows + 1:end])
                elseif widthbytes == 2
                    widths = reinterpret(Int16, a[13 .+ (1:2*info.nrows)])
                    io = IOBuffer(a[13 + 2*info.nrows + 1:end])
                else
                    throw(ErrorException("Unknown `widthbytes=$widthbytes`, some offset is wrong somewhere, column i=$i"))
                end
            else # uncompressed
                # continue after dt1,...,dt5 were read
                _read_reals!(raw, offset, UInt8, 5)
                hasunits = _read_real!(raw, offset, UInt8)
                _read_reals!(raw, offset, UInt8)
                n1 = _read_real!(raw, offset, Int64)
                if hasunits == 1 && n1 > 0
                    _read_real!(raw, offset, Int16) # ??
                    _read_real!(raw, offset, Int64) # some length
                    label = _read_string!(raw, offset, 4)
                    _read_real!(raw, offset, UInt32)
                end
                _read_real!(raw, offset, UInt16) # n2 as bytes
                n2 = _read_real!(raw, offset, UInt32)
                _read_reals!(raw, offset, UInt8, n2)
                _read_real!(raw, offset, UInt64) # 8 bytes
                widthbytes = _read_real!(raw, offset, UInt8)
                maxwidth = _read_real!(raw, offset, UInt32)
                if widthbytes == 0x01 # Int8
                    widths = _read_reals!(raw, offset, Int8, info.nrows)
                elseif widthbytes == 0x02 # Int16
                    widths = _read_reals!(raw, offset, Int16, info.nrows)
                elseif widthbytes == 0x04 # Int32
                    widths = _read_reals!(raw, offset, Int32, info.nrows)
                else
                    throw(ErrorException("Unknown `widthbytes=$widthbytes`, some offset is wrong somewhere, column i=$i"))
                end
                io = IOBuffer(raw[end-sum(widths)+1:end])
            end

            str = [String(read(io, widths[i])) for i in 1:info.nrows]
            return str
        end
    end

    @error("Data type combination `(dt1,dt2,dt3,dt4,dt5)=$dt1,$dt2,$dt3,$dt4,$dt5` not implemented, found in column `$(info.column.names[i])` (i=$i), returning a vector of NaN's")
    return fill(NaN, info.nrows)
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
