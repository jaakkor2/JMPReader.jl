function metadata(io)
    seekstart(io)
    seq = [0x07, 0x00, 0x08, 0x00, 0x00, 0x00]
    readuntil(io, seq)
    seek(io, position(io) - 38)

    nrows = read(io, Int64)
    ncols = read(io, Int32)
    foo1 = read_reals(io, Int16, 5) # ??
    charset = rstrip(_read_string!(io, 4), '\0')
    foo2 = read_reals(io, UInt16, 3)
    savetime = to_datetime([read(io, Float64)])[1]
    foo3 = read(io, UInt16) ## 18
    buildstring = _read_string!(io, 4)
    m = match(r"Version (?<version>.*)$", buildstring)
    isnothing(m) && throw(ErrorException("Could not determine JMP version"))
    version = VersionNumber(m["version"])

    # brute-force find the offset to column data index
    n_visible, n_hidden = seek_to_column_data_offsets(io, ncols)
    idx_visible = read_reals(io, UInt32, n_visible)
    idx_hidden = read_reals(io, UInt32, n_hidden)
    colwidths = read_reals(io, UInt16, ncols)
    read_reals(io, UInt32, 7) # ??
    
    colnames, coloffsets = JMPReader.column_info(io, ncols)

    Info(version, buildstring, savetime, nrows, ncols, Column(colnames, colwidths, coloffsets))
end

"""
    column_info(data, ncols)

Return column names and offsets to column data.
"""
function column_info(io, ncols)
    while true
        twobytes = read(io, 2)
        # TODO below is not correct since number of column (UInt32) might match with the two bytes listed below.
        if twobytes in [[0xfd, 0xff], [0xfe, 0xff], [0xff, 0xff]] # ?? hacky
            n = read(io, Int64)
            read_reals(io, UInt8, n)
        else
            skip(io, -2) # no negative number was found, go back
            break
        end
    end
    ncols2 = read(io, Int32)
    ncols == ncols2 || throw(ErrorException("Number of columns read from two locations do not match.  Likely a problem in `column_info`-function. $ncols vs $ncols2"))
    coloffsets = read_reals(io, Int64, ncols)
    colnames = String[]
    for i in coloffsets
        seek(io, i)
        push!(colnames, _read_string!(io, 2))
    end
    return colnames, coloffsets
end

function seek_to_column_data_offsets(io, ncols)
    seekstart(io)
    skip(io, 2)
    while true
        readuntil(io, [0xff, 0xff])
        # skip to the end of 0xff's
        while peek(io) == 0xff
            skip(io, 1)
        end
        eof(io) && throw(ErrorException("Could not find column offset data"))
        skip(io, 10)
        n_visible = read(io, UInt32)
        n_hidden = read(io, UInt32)
        skip(io, 4+4) # unknown
        n_visible + n_hidden == ncols && return n_visible, n_hidden
        skip(io, -18)
    end
end