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

    # brute-force find the offset to column data index
    idx = findfirst(reinterpret(UInt8, Int32.(0:ncols-1)), a)
    isnothing(idx) && error("Column index not found.")
    offset = [idx[1] - 16 - 1]

    ncols2 = _read_real!(a, offset, Int32)
    ncols == ncols2 || @error("Number of columns from two different locations do not match, $ncols vs $ncols2")

    unknowns6 = _read_reals!(a, offset, Int16, 6) # ??

    colidxlist = _read_reals!(a, offset, Int32, ncols)
    colidxlist == 0:ncols-1 || @warn("`offset_colinfo`-variable probably has a wrong value")

    colformatting = _read_reals!(a, offset, UInt16, ncols) # ??

    colnames, coloffsets = column_info(a, offset[1], ncols)
    
    Info(buildstring, savetime, nrows, ncols, Column(colnames, colformatting, coloffsets))
end

"""
    column_info(data, offset, ncols)

Return column names and offsets to column data.
"""
function column_info(data, offset, ncols)
    hacky_offset = data[offset + 31] + 42 # TODO needs improvement
    coloffsets = reinterpret(Int64, data[offset + hacky_offset .+ (1:8*ncols)])
    colnames = String[]
    for i in coloffsets
        width = reinterpret(Int16, data[1+i:2+i])[1]
        push!(colnames, String(data[2+i .+ (1:width)]))
    end
    return colnames, coloffsets
end
