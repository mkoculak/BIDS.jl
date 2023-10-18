abstract type Modality end

mutable struct Generic <: Modality
    path::String
    files::Vector{String}
end

Base.show(io::IO, gen::Generic) = print(io, "Generic ($(length(gen.files)) files)")

function _get_unique_elements(sections)
    elements = unique(sections)
    
    # Remove elements that are subsets of some other elements
    nonUnqInd = Int[]

    for unq in eachindex(elements)
        occurences = sum(map(x -> issubset(elements[unq], x), elements))
        occurences > 1 ? push!(nonUnqInd, unq) : nothing
    end

    deleteat!(elements, nonUnqInd)

    return elements
end

function _get_all_subset_files(element, sections, files)
    elemIdx = Int[]
    for idx in eachindex(element)
        append!(elemIdx, findall(x -> element[1:idx] == x, sections))
    end
    return files[elemIdx]
end

function _check_label(row, pathLabel, fileLabel)
    if !haskey(row, fileLabel)
        @warn "Filename is missing proper label $fileLabel" _id=fileLabel
    elseif row[pathLabel] != fileLabel * "-" * row[fileLabel]
        @warn "Label $fileLabel not match path $pathLabel" _id=fileLabel
    end
    delete!(row, fileLabel)
end

function _parse_mod_files!(::Type{Generic}, path, mod, modalities, modalityRow)
    files = readdir(joinpath(path, mod))
    # Ignore the last section that contains modality specific descriptor and extension
    sections = map(x -> split.(basename(x), '_')[1:end-1], files)

    uniqueElements = _get_unique_elements(sections)

    elemFiles = String[]
    for element in uniqueElements
        row = copy(modalityRow)
        try
            for part in element
                col, val = split(part, '-')
                row[col] = val
            end
            
            append!(elemFiles, _get_all_subset_files(element, sections, files))
        catch
            el = join(element, "_")
            @warn "Error parsing element $el in path: $(joinpath(path, mod))" _id=el
        end
        row["files"] = Generic(path, elemFiles)

        # Check if subject label from file matches the path and remove the one from file
        _check_label(row, "participant_id", "sub")
        # Same check for session label if present in filename
        haskey(row, "ses") && _check_label(row, "session", "ses")

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