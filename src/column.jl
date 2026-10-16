"""
    column_data(io, info, i::Int, deflatebuffer::Vector{UInt8})

Return data from `i`th column.
"""
function column_data(io, info, i::Int, deflatebuffer::Vector{UInt8})
    1 ≤ i ≤ info.ncols || error("requested column $i is out-of-bounds")
    
    seek(io, info.column.offsets[i])

    columnname = _read_string!(io, 2)
    lenname = length(columnname)
    dt1, dt2, dt3, dt4, dt5, dt6 = read_reals(io, UInt8, 6)
    mark(io)

    # compressed
    if dt1 in (0x09, 0x0a)
        readuntil(io, GZIP_SECTION_START)
        gziplen = read(io, UInt64)
        gunziplen = read(io, UInt64)
        raw = mmap(io, Vector{UInt8}, gziplen)
        if gunziplen < 2^32
            decomp_status = gzip_decompress!(Decompressor(), deflatebuffer, raw, max_len = gunziplen)
            decomp_status == LibDeflateErrors.deflate_insufficient_space && error("deflate insufficient space")
            a = @view deflatebuffer[1:Int(gunziplen)]
        else
            # fall back to CodecZlib that handles > 2^32 buffers
            a = transcode(GzipDecompressor, raw)
        end
    else
        colend = i == info.ncols ? position(seekend(io)) : info.column.offsets[i+1]
        seek(io, info.column.offsets[i])
        a = mmap(io, Vector{UInt8}, colend - position(io) )
        reset(io)
    end

    # one of Float64, Date, Time, Duration, byte integer
    # dt3 = format width
    if dt1 in (0x01, 0x0a)
        T = dt6 == 0x01 ? Int8 : dt6 == 0x02 ? Int16 : dt6 == 0x04 ? Int32 : dt6 == 0x08 ? Float64 : error("Unknown numeric storage width dt6=$dt6 in column $i")
        out = reinterpret(T, @view a[end-dt6*info.nrows+1:end])
        out = sentinel2missing(out)

        # Float64 or byte integers
        if  (dt4 == dt5 && dt4 in (0x00, 0x03, 0x42, 0x43, 0x44, 0x59, 0x60, 0x63)) ||
            dt5 in (0x5e, 0x63) # fixed dec, dt3=width, dt4=dec

            return out
        end
        # Currency
        if dt4 == dt5 && dt4 in CURRENCY_FORMATS
            return out
        end
        # Longitude
        if dt4 == dt5 && dt4 in LONGITUDE_FORMATS
            return out
        end
        # Latitude
        if dt4 == dt5 && dt4 in LATITUDE_FORMATS
            return out
        end
        
        # then it is a date, time or duration
        out = to_datetime(out)
        # dt4=format, dt5=input format
        # Date
        if dt4 in DATE_FORMATS
            return [ismissing(x) ? missing : Date(x) for x in out]
        end
        # DateTime
        if dt4 in DATETIME_FORMATS
            return [ismissing(x) ? missing : DateTime(x) for x in out]
        end
        # Duration
        if dt4 in DURATION_FORMATS
            return [ismissing(x) ? missing : x - JMP_STARTDATE for x in out]
        end
    end

    # byte integer
    if dt1 in (0xff, 0xfe, 0xfc)
        T = dt5 == 0x01 ? Int8 : dt5 == 0x02 ? Int16 : dt5 == 0x04 ? Int32 : dt5 == 0x08 ? Float64 : error("Unknown numeric storage width dt5=$dt5 in column $i")
        out = reinterpret(T, @view a[end-dt5*info.nrows+1:end])
        out = sentinel2missing(out)
        return out
    end

    # row states
    if dt1 == 0x09 && dt2 == 0x03
        width = dt5
        rs = Rowstate[]
        for row in 1:info.nrows
            offset = width * (row - 1)
            markeridx = bitcat(a[offset + 7], a[offset + 6])
            marker = markeridx ≤ 0x001f ? rowstatemarkers[markeridx + 1] : Char(markeridx)
            if a[offset + 4] == 0xff
                r, g, b = nor(a[offset + 3]), nor(a[offset + 2]), nor(a[offset + 1])
            else
                r, g, b = hex2bytes(lstrip(rowstatecolors[a[offset + 1] + 1], '#'))
            end
            color = RGB(r / 255, g / 255, b / 255)
            push!(rs, Rowstate(marker, color))
        end
        return rs
    end
    if dt1 == 0x03 && dt2 == 0x03
        width = dt5
        T = Int64
        out = reinterpret(T, @view a[end - width*info.nrows+1:end])
        return out
    end

    # character
    if dt1 in (0x02, 0x09) && dt2 in (0x01, 0x02)

        # constant width
        if ((dt3, dt4) == (0x00, 0x00) && dt5 > 0) ||
            (0x01 ≤ dt3 ≤ 0x07 && dt4 == 0x00)
            width = dt5
            data = a[end-info.nrows*width+1:end]
            str = to_str(data, info.nrows, width)
            return str
        end
        
        # variable width
        if (dt3, dt4, dt5) == (0x00, 0x00, 0x00)
            if dt1 == 0x09 # compressed
                if reinterpret(Int64, a[1:8])[1] == length(a) # pooled data
                    io2 = IOBuffer(a)
                    reclen = read(io2, Int64)
                    foo = read(io2, 9)
                    foo2 = read(io2, Int64)
                    # indices to pool
                    wb = read(io2, Int8)
                    T = Dict(1 => UInt8, 2 => UInt16, 4 => UInt32)[wb]
                    idx = [read(io2, T) for _ in 1:info.nrows]
                    # pool
                    npools = maximum(idx)
                    wb = read(io2, Int8)
                    T = wb == 1 ? Int8 : wb == 2 ? Int16 : error()
                    pool = String[]
                    for _ = 1:npools
                        n = read(io2, T)
                        push!(pool, String(read(io2, n)))
                    end
                    str = [j == 0 ? "" : pool[j] for j in idx]
                    return str
                else
                    widthbytes = a[9]
                    if widthbytes == 1
                        widths = reinterpret(Int8, @view a[13 .+ (1:info.nrows)])
                        data = a[13 + info.nrows + 1:end]
                    elseif widthbytes == 2
                        widths = reinterpret(Int16, @view a[13 .+ (1:2*info.nrows)])
                        data = a[13 + 2*info.nrows + 1:end]
                    else
                        throw(ErrorException("Unknown `widthbytes=$widthbytes`, some offset is wrong somewhere, column i=$i"))
                    end
                end
            else # uncompressed
                # continue after dt1,...,dt6 were read
                skip(io, 6)
                n1 = read(io, Int64)
                skip(io, n1)
                skip(io, 2) # n2 as bytes
                n2 = read(io, UInt32)
                skip(io, n2 + 8)
                widthbytes = read(io, UInt8)
                maxwidth = read(io, UInt32)
                widthtype = widthbytes == 0x01 ? Int8 : widthbytes == 0x02 ? Int16 : widthbytes == 0x04 ? Int32 : throw(ErrorException("Unknown `widthbytes=$widthbytes`, some offset is wrong somewhere, column i=$i"))
                widths = read_reals(io, widthtype, info.nrows)
                data = mmap(seek(io, colend - sum(widths)), Vector{UInt8}, sum(widths))
            end
            str = to_str(data, info.nrows, widths)
            return str
        end
    end

    @error("Data type combination `(dt1,dt2,dt3,dt4,dt5,dt6)=$dt1,$dt2,$dt3,$dt4,$dt5,$dt6` not implemented, found in column `$(info.column.names[i])` (i=$i), returning a vector of NaN's")
    return fill(NaN, info.nrows)
end
