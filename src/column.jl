"""
    column_data(data, info, i::Int)

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
    if dt1 in [0x09, 0x0a]
        readuntil(io, GZIP_SECTION_START)
        gziplen = read(io, UInt64)
        gunziplen = read(io, UInt64)
        raw = mmap(io, Vector{UInt8}, gziplen)
        if gunziplen < 2^32
            decomp_status = gzip_decompress!(Decompressor(), deflatebuffer, raw, max_len = gunziplen)
            decomp_status == LibDeflateErrors.deflate_insufficient_space && @error "deflate insufficient space"
            a = deflatebuffer
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
    if dt1 in [0x01, 0x0a]
        T = dt6 == 0x01 ? Int8 : dt6 == 0x02 ? Int16 : dt6 == 0x04 ? Int32 : Float64
        out = reinterpret(T, @view a[end-dt6*info.nrows+1:end])
        out = sentinel2missing(out)

        # Float64 or byte integers
        if  (dt4 == dt5 && dt4 in [
            0x00, 0x03, 0x42, 0x43, 0x44, 0x59, 0x60, 0x63,
            ]) ||
            dt5 in [0x5e, 0x63] # fixed dec, dt3=width, dt4=dec

            return out
        end
        # Currency
        if dt4 == dt5 && dt4 in [0x5f]
            return out
        end
        # Longitude
        if dt4 == dt5 && dt4 in [0x54, 0x55, 0x56]
            return out
        end
        # Latitude
        if dt4 == dt5 && dt4 in [0x51, 0x52, 0x53]
            return out
        end
        
        # then it is a date, time or duration
        out = to_datetime(out)
        # Date
        if (dt4 == dt5 && dt4 in [
            0x65, 0x66, 0x67, 0x6e, 0x6f, 0x70, 0x71, 0x72, 0x75, 0x76, 0x7a,
            0x7f, 0x88, 0x8b,
            ]) ||
            [dt4, dt5] in [[0x67, 0x65], [0x6f, 0x65], [0x72, 0x65], [0x72, 0x6f], [0x72, 0x7f], [0x72, 0x80], [0x7f, 0x72], [0x88, 0x65], [0x88, 0x7a]]

            return [ismissing(x) ? missing : Date(x) for x in out]
        end
        # DateTime
        if dt5 in [0x69, 0x6a, 0x73, 0x74, 0x77, 0x78, 0x7e, 0x81] && dt4 in [
            0x69, 0x6a, 0x6c, 0x6d, 0x73, 0x74, 0x77, 0x78, 0x79, 0x7b, 0x7c,
            0x7d, 0x7e, 0x80, 0x81, 0x82, 0x86, 0x87, 0x89, 0x8a,
            ] ||
            dt4 == dt5 in [0x79, 0x7d] ||
            [dt4, dt5] in [[0x77, 0x80], [0x77, 0x7f], [0x89, 0x65]]

            return [ismissing(x) ? missing : DateTime(x) for x in out]
        end
        # Time
        if dt4 == dt5 in [0x82]

            return [ismissing(x) ? missing : Time(x) for x in out]
        end
        # Duration
        if dt4 == dt5 && dt4 in [
            0x0c, 0x6b, 0x6c, 0x6d, 0x83, 0x84, 0x85
            ] ||
            [dt4, dt5] in [[0x84, 0x79]]

            return [ismissing(x) ? missing : DateTime(x) - JMP_STARTDATE for x in out]
        end
    end

    # byte integer
    if dt1 in [0xff, 0xfe, 0xfc]
        T = dt5 == 0x01 ? Int8 : dt5 == 0x02 ? Int16 : dt5 == 0x04 ? Int32 : Float64
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
    if dt1 in [0x02, 0x09] && dt2 in  [0x01, 0x02]

        # constant width
        if ([dt3, dt4] == [0x00, 0x00] && dt5 > 0) ||
            (0x01 ≤ dt3 ≤ 0x07 && dt4 == 0x00)
            width = dt5
            data = a[end-info.nrows*width+1:end]
            str = to_str(data, info.nrows, width)
            return str
        end
        
        # variable width
        if [dt3, dt4, dt5] == [0x00, 0x00, 0x00]
            if dt1 == 0x09 # compressed
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
