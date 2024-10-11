function _read_string!(io, width)
    width in [1,2,4] || throw(ArgumentError("Invalid string width $(width)"))
    type = width == 1 ? Int8 : width == 2 ? Int16 : Int32
    len = read(io, type)
    str = String(read(io, len))
    return str
end

function read_reals(io, type, len = 1)
    type <: Real || throw(ArgumentError("Specified type $type is not a real type"))
    width = sizeof(type)
    if mod(position(io), width) == 0 # proper alignment
        reals = mmap(io, Vector{type}, len)
        skip(io, width*len)
    else
        reals = [read(io, type) for _ in 1:len]
    end
    return reals
end

"""
    to_datetime(floats::AbstractVector{Float64})

Convert a of `Float64`s to a vector of `DateTime`s.
JMP uses the 1904 date system, correct for that.
"""
function to_datetime(floats::AbstractVector{T}) where T <: Union{Missing,Float64}
    dt = [ismissing(float) ? missing : unix2datetime(float) for float in floats]
    dt .- (unix2datetime(0) - JMP_STARTDATE)
end

function check_magic(io)
    magic = read(io, length(MAGIC_JMP))
    magic == MAGIC_JMP
end

function to_str(buffer, n, lengths::AbstractVector)
    str = StringVector{String}(buffer, Int(n))
    str.lengths .= lengths
    offset = UInt64(0)
    @inbounds for i in 1:n
        str.offsets[i] = offset
        offset += lengths[i]
    end
    str
end

function to_str(buffer, n, length::Integer)
    str = StringVector{String}(buffer, Int(n))
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

function filter_columns(names, include_columns, exclude_columns)
    cols = 1:length(names)
    if !isnothing(include_columns)
        cols = intersect(cols, filter_names(names, include_columns))
    end
    if !isnothing(exclude_columns)
        cols = setdiff(cols, filter_names(names, exclude_columns))
    end
    cols = sort(cols)
    return cols
end

function filter_names(names, rules)
    idx = Int[]
    for rule in rules
        isa(rule, Integer) && push!(idx, rule)
        isa(rule, OrdinalRange) && append!(idx, rule)
        isa(rule, String) && push!(idx, findfirst(==(rule), names))
        isa(rule, Symbol) && push!(idx, findfirst(==(String(rule)), names))
        isa(rule, Regex) && append!(idx, findall(contains.(names, rule)))
    end
    return idx
end

# https://discourse.julialang.org/t/newbie-question-convert-two-8-byte-values-into-a-single-16-byte-value/7662/4?u=jaakkor2
bitcat(a::UInt8, b::UInt8) = (UInt16(a) << 8) | b

function sentinel2missing(data)
    T = eltype(data)
    if T == Float64
        sentinel = NaN
        eq = isnan
    else
        sentinel = typemin(T) + 1
        eq = ==(sentinel)
    end
    if !isnothing(findfirst(eq, data))
        data = replace(data, sentinel => missing) # materialize
    end
    data
end