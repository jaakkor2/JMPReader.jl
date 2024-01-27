function _read_string!(a, offset, width)
    width in [1,2,4] || throw(ArgumentError("Invalid string width $(width)"))
    type = width == 1 ? Int8 : width == 2 ? Int16 : Int32
    len = _read_real!(a, offset, type)
    str = String(a[offset[1] .+ (1:len)])
    offset[1] += len
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
    to_datetime(floats::AbstractVector{Float64})

Convert a of `Float64`s to a vector of `DateTime`s.
JMP uses the 1904 date system, correct for that.
"""
function to_datetime(floats::AbstractVector{Float64})
    dt = [isnan(float) ? missing : unix2datetime(float) for float in floats]
    dt .- (unix2datetime(0) - JMP_STARTDATE)
end

function check_magic(a, fn)
    len = length(a)
    len ≥ length(MAGIC_JMP) && a[1:length(MAGIC_JMP)] == MAGIC_JMP || throw(ArgumentError("Data table appears to have been corrupted, or is not a .jmp file. `$fn` "))
    len < 507 && throw(ArgumentError("Data table appears to have been corrupted. `$fn`"))
    nothing
end

function to_str(buffer, n, lengths::AbstractVector)
    str = StringVector{String}(buffer, n)
    str.lengths .= lengths
    offset = UInt64(0)
    @inbounds for i in 1:n
        str.offsets[i] = offset
        offset += lengths[i]
    end
    str
end

function to_str(buffer, n, length::Integer)
    str = StringVector{String}(buffer, n)
    str.lengths .= length
    offset = UInt64(0)
    @inbounds for i in 1:n
        str.offsets[i] = offset
        offset += length
    end
    rstripnull!(str)
    str
end

"""
    rstripnull!(strs::StringVector)

Remove trailing nulls from `strs`.
"""
function rstripnull!(s::StringVector)
    @inbounds for (i, (length, offset)) in enumerate(zip(s.lengths, s.offsets))
        while s.buffer[offset + length] == 0x00 && length > 0
            length -= 1
        end
        s.lengths[i] = length
    end
    nothing
end