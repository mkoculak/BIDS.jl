abstract type EEGFile end

struct BDF <: EEGFile end
struct EDF <: EEGFile end
struct BVF <: EEGFile end
struct SET <: EEGFile end
struct OTHER <: EEGFile end

EEGFilter = Dict{String, Dict{String, Union{Number, String}}}

mutable struct EEGDescription
    TaskName::Union{String, Nothing}                        # required
    InstitutionName::Union{String, Nothing}                 # recommended
    InstitutionAddress::Union{String, Nothing}              # recommended
    InstitutionalDepartmentName::Union{String, Nothing}     # recommended
    Manufacturer::Union{String, Nothing}                    # recommended
    ManufacturersModelName::Union{String, Nothing}          # recommended
    SoftwareVersions::Union{String, Nothing}                # recommended
    TaskDescription::Union{String, Nothing}                 # recommended
    Instructions::Union{String, Nothing}                    # recommended
    CogAtlasID::Union{String, Nothing}                      # recommended
    CogPOID::Union{String, Nothing}                         # recommended
    DeviceSerialNumber::Union{String, Nothing}              # recommended
    EEGReference::Union{String, Nothing}                    # required
    SamplingFrequency::Union{Number, String, Nothing}       # required
    PowerLineFrequency::Union{Number, String, Nothing}      # required
    SoftwareFilters::Union{EEGFilter, String, Nothing}      # required
    CapManufacturer::Union{String, Nothing}                 # recommended
    CapManufacturersModelName::Union{String, Nothing}       # recommended
    EEGChannelCount::Union{Int, Nothing}                    # recommended
    ECGChannelCount::Union{Int, Nothing}                    # recommended
    EMGChannelCount::Union{Int, Nothing}                    # recommended
    EOGChannelCount::Union{Int, Nothing}                    # recommended
    MiscChannelCount::Union{Int, Nothing}                   # recommended
    TriggerChannelCount::Union{Int, Nothing}                # recommended
    RecordingDuration::Union{Number, Nothing}               # recommended
    RecordingType::Union{String, Nothing}                   # recommended
    EpochLength::Union{Number, Nothing}                     # recommended
    EEGGround::Union{String, Nothing}                       # recommended
    HeadCircumference::Union{Number, Nothing}               # recommended
    EEGPlacementScheme::Union{String, Nothing}              # recommended
    HardwareFilters::Union{EEGFilter, String, Nothing}      # recommended
    SubjectArtefactDescription::Union{String, Nothing}      # recommended
end

function _get_eeg_description(lay, cwd, sameFiles)
    descPath = filter(endswith("_eeg.json"), joinpath.(cwd, sameFiles))

    if isempty(descPath)
        @warn "Missing EEG json file at $cwd" _id="EEG Description"
        return nothing
    elseif length(descPath) > 1
        @warn "Multiple files matching the EEG json filename at $cwd. \
        Reading the first from the list." _id="EEG Description"
        return read_json(lay, descPath[1], EEGDescription)
    else
        return read_json(lay, descPath[1], EEGDescription)
    end
end



mutable struct EEG{T<:EEGFile} <: Modality
    Description::Union{EEGDescription, Nothing}
    path::String
    files::Vector{String}
end

Base.show(io::IO, eeg::EEG{T}) where T = print(io, "EEG{$(split(string(T),'.')[2])} ($(length(eeg.files)) files)")



function _parse_mod_files!(::Type{EEG}, lay, path, mod, modalities, modalityRow)
    cwd = joinpath(path, mod)
    files = readdir(cwd)
    # Ignore the last section that contains modality specific descriptor and extension
    sections = map(x -> split.(basename(x), '_')[1:end-1], files)

    uniqueElements = _get_unique_elements(sections)

    for element in uniqueElements
        row = copy(modalityRow)
        for part in element
            col, val = split(part, '-')
            row[col] = val
        end
        
        sameFiles = _get_all_subset_files(element, sections, files)
        ext = map(x -> splitext(x)[2], sameFiles)

        if ".bdf" in ext
            param = BDF
        elseif ".edf" in ext
            param = EDF
        elseif ".eeg" in ext
            param = BVF
        elseif ".set" in ext
            param = SET
        else
            param = OTHER
        end

        # Parse the JSON sidecar
        description = _get_eeg_description(lay, cwd, sameFiles)


        row["files"] = EEG{param}(description, path, sameFiles)

        push!(modalities, row)
    end
end

# Add new type to the parser list
parsers["eeg"] = EEG