function metadata(a)
    offset = [offset_nrows]
    nrows = _read_real!(a, offset, Int64)
    ncols = _read_real!(a, offset, Int32)
    foo1 = _read_reals!(a, offset, Int16, 5) # ??
    charset = rstrip(_read_string!(a, offset, 4), '\0')
    foo2 = _read_reals!(a, offset, UInt16, 3) # ?? 7,8,0
    savetime = to_datetime([_read_real!(a, offset, Float64)])[1]
    foo3 = _read_real!(a, offset, UInt16) ## 18
    buildstring = _read_string!(a, offset, 4)
    m = match(r"Version (?<version>.*)$", buildstring)
    isnothing(m) && throw(ErrorException("Could not determine JMP version"))
    version = VersionNumber(m["version"])

    # brute-force find the offset to column data index
    offset = find_column_data_offset(a, ncols)

    unknowns6 = _read_reals!(a, offset, Int16, 6) # ??

    colidxlist = _read_reals!(a, offset, Int32, ncols)
    colidxlist == 0:ncols-1 || @warn("`offset_colinfo`-variable probably has a wrong value")

    colformatting = _read_reals!(a, offset, UInt16, ncols) # ??
    _read_reals!(a, offset, UInt32, 7) # ??

    colnames, coloffsets = column_info(a, offset, ncols)

    Info(version, buildstring, savetime, nrows, ncols, Column(colnames, colformatting, coloffsets))
end

"""
    column_info(data, offset, ncols)

Return column names and offsets to column data.
"""
function column_info(data, offset, ncols)
    if _read_reals!(data, offset, UInt8, 2) == [0xfd, 0xff] # ?? hacky
        n = _read_real!(data, offset, Int64)
        _read_reals!(data, offset, UInt8, n) # ??
    else
        offset .-= 2 # [0xfd, 0xff] was not found, go back
    end   
    ncols2 = _read_real!(data, offset, Int32)
    ncols == ncols2 || throw(ErrorException("Number of columns read from two locations do not match.  Likely a problem in `column_info`-function."))
    coloffsets = _read_reals!(data, offset, Int64, ncols)
    colnames = String[]
    for i in coloffsets
        push!(colnames, _read_string!(data, [i], 2))
    end
    return colnames, coloffsets
end

function find_column_data_offset(a, ncols)
    bytestofind = reinterpret(UInt8, Int32.(0:ncols-1))
    start = 17
    while true
        idx = findnext(bytestofind, a, start)
        isnothing(idx) && throw(ErrorException("Column index not found."))
        offset = [idx[1] - 16 - 1]
        ncols2 = _read_real!(a, offset, Int32)
        ncols == ncols2 && return offset
        start = idx[2] + 1
    end
end