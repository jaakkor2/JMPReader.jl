function _read_string!(a, offset, width)
    width in [1,2,4] || throw(ArgumentError("Invalid string width $(width)"))
    type = width == 1 ? Int8 : width == 2 ? Int16 : Int32
    len = reinterpret(type, a[offset .+ (1:width)])[1]
    str = String(a[offset[1] + width .+ (1:len)])
    offset[1] += width + len
    return str
end

function _read_reals!(a, offset, type, len = 1)
    type <: Real || throw(ArgumentError("Specified type $type is not a real type"))
    width = sizeof(type)
    reals = reinterpret(type, a[offset[1] .+ (1:len*width)])
    offset[1] += len*width
    return reals
end

_read_real!(a, offset, type) = _read_reals!(a, offset, type)[1]

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

function check_magic(a, fn)
    len = length(a)
    len ≥ length(magic) && a[1:length(magic)] == magic || throw(ArgumentError("\"$fn\" is not a .jmp"))
    len < 507 && throw(ArgumentError("\"$fn\" truncated?"))
    nothing
end