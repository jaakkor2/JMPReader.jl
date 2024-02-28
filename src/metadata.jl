function metadata(io)
    seek(io, OFFSET_NROWS)
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
    offset = find_column_data_offset(io, ncols)
    seek(io, offset)
    ncols2 = read(io, UInt32)
    unknown6 = read_reals(io, UInt16, 6) # ??

    colidxlist = read_reals(io, Int32, ncols)
    colidxlist == 0:ncols-1 || @warn("`offset_colinfo`-variable probably has a wrong value")
    
    colformatting = read_reals(io, UInt16, ncols) # ??
    read_reals(io, UInt32, 7) # ??
    
    colnames, coloffsets = JMPReader.column_info(io, ncols)

    Info(version, buildstring, savetime, nrows, ncols, Column(colnames, colformatting, coloffsets))
end

"""
    column_info(data, ncols)

Return column names and offsets to column data.
"""
function column_info(io, ncols)
    while true
        twobytes = read_reals(io, UInt8, 2)
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

function find_column_data_offset(io, ncols)
    bytestofind = reinterpret(UInt8, Int32.(0:ncols-1))
    seekstart(io)
    while true
        readuntil(io, bytestofind)
        skip(io, -length(bytestofind) - 16)
        ncols2 = read(io, Int32)
        ncols == ncols2 && return position(io) - 4
        skip(io, 16)
    end
end