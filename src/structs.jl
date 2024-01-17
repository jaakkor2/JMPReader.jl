struct Column
    names::Vector{String}
    unknown::Vector{UInt16}
    offsets::Vector{Int64}
end

struct Info
    buildnumber::Int16
    buildmonth::String
    proversion::Bool
    savetime::DateTime
    nrows::Int64
    ncols::Int32
    column::Column
end
