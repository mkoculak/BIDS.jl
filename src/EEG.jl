abstract type EEGFile end

struct BDF <: EEGFile end
struct EDF <: EEGFile end
struct BVF <: EEGFile end
struct SET <: EEGFile end
struct OTHER <: EEGFile end

mutable struct EEG{T<:EEGFile} <: Modality
    path::String
    files::Vector{String}
end

Base.show(io::IO, eeg::EEG{T}) where T = print(io, "EEG{$(split(string(T),'.')[2])} ($(length(eeg.files)) files)")

# Add new type to the parser list
parsers["eeg"] = EEG

function _parse_mod_files!(::Type{EEG}, path, mod, modalities, modalityRow)
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
        
        sameFiles = filter(x -> contains(x, join(element, '_')), files)
        ext = map(x -> splitext(x)[2], sameFiles)

        if ".bdf" in ext
            param = BDF
        elseif ".edf" in ext
            param = EDF
        elseif ".egg" in ext
            param = BVF
        elseif ".set" in ext
            param = SET
        else
            param = OTHER
        end
        row["files"] = EEG{param}(path, sameFiles)

        push!(modalities, row)
    end
end