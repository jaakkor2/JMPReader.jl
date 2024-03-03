struct Column
    names::Vector{String}
    widths::Vector{UInt16} # display column widths
    offsets::Vector{Int64}
end

struct Info
    version::VersionNumber
    buildstring::String
    savetime::DateTime
    nrows::Int64
    ncols::Int32
    column::Column
end

struct Rowstate
    marker::Char
    color::RGB{N0f8}
end