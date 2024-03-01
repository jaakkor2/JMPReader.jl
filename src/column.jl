"""
    column_data(data, info, i::Int)

Return data from `i`th column.
"""
function column_data(io, info, i::Int, deflatebuffer::Vector{UInt8})
    1 ≤ i ≤ info.ncols || error("requested column $i is out-of-bounds")
    
    seek(io, info.column.offsets[i])

    columnname = _read_string!(io, 2)
    lenname = length(columnname)
    dt1, dt2, dt3, dt4, dt5 = read_reals(io, UInt8, 5)
#    @show dt1, dt2, dt3, dt4, dt5
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
    
    # one of Float64, Date, Time, Duration
    # dt3 = format width
    if dt1 in [0x01, 0x0a]
        if dt3 == 0x04 
            @error "i=$i, dt3=$dt3 not handled properly"
            return fill(NaN, info.nrows)
        end

        out = reinterpret(Float64, @view a[end-8*info.nrows+1:end])
        # Float64
        if  (dt4 == dt5 && dt4 in [
            0x00, 0x03, 0x42, 0x43, 0x59, 0x60, 0x63,
            ]) ||
            dt5 in [0x5e] # fixed dec, dt3=width, dt4=dec

            out = replace(out, NaN => missing) # materialize
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
            ] ||
            dt4 == dt5 in [0x7d]

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
                # continue after dt1,...,dt5 were read
                read_reals(io, UInt8, 5)
                hasprops = read(io, UInt8)
                read(io, UInt8)
                n1 = read(io, Int64)
                if hasprops == 1
                    # some block that ends in [0xff, 0xff, 0xff, 0xff]
                    readuntil(io, [0xff, 0xff, 0xff, 0xff])
                end
                read(io, UInt16) # n2 as bytes
                n2 = read(io, UInt32)
                read_reals(io, UInt8, n2)
                read(io, UInt64) # 8 bytes
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

    @error("Data type combination `(dt1,dt2,dt3,dt4,dt5)=$dt1,$dt2,$dt3,$dt4,$dt5` not implemented, found in column `$(info.column.names[i])` (i=$i), returning a vector of NaN's")
    return fill(NaN, info.nrows)
end
