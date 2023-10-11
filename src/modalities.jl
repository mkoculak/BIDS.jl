abstract type Modality end

mutable struct Generic <: Modality
    path::String
    files::Vector{String}
end

Base.show(io::IO, gen::Generic) = print(io, "Generic ($(length(gen.files)) files)")

function _parse_mod_files!(::Type{Generic}, path, mod, modalities, modalityRow)
    files = readdir(joinpath(path, mod))
    # Ignore the last section that contains modality specific descriptor and extension
    sections = map(x -> split.(basename(x), '_')[1:end-1], files)

    uniqueElements = unique(sections)

    for element in uniqueElements
        row = copy(modalityRow)
        for part in element
            col, val = split(part, '-')
            row[col] = val
        end
        
        row["files"] = Generic(path, filter(x -> contains(x, join(element, '_')), files))
        push!(modalities, row)
    end
end

const parsers = Dict{String, Type{<:Modality}}(
    "other" => Generic
)

function _parse_mod_files!(path::String, mod::String, modalities, modalityRow)
    if mod ∈ keys(parsers)
        _parse_mod_files!(parsers[mod], path, mod, modalities, modalityRow)
    else
        _parse_mod_files!(parsers["other"], path, mod, modalities, modalityRow)
    end
end