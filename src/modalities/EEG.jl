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

mutable struct EEGChannels
    data::Union{DataFrame, Nothing}
    metadata::Union{Dict{Symbol, TabularMeta}, Nothing}
end

function _get_eeg_channels(lay, cwd, sameFiles)
    chanPath = filter(endswith("_channels.tsv"), joinpath.(cwd, sameFiles))
    chanMetaPath = filter(endswith("_channels.json"), joinpath.(cwd, sameFiles))

    if isempty(chanPath)
        chans = nothing
    elseif length(chanPath) > 1
        @warn "Multiple files matching the channels filename at $cwd. \
        Reading the first from the list." _id="EEG Channels"
        chans = read_tsv(lay, chanPath[1], DataFrame)
    else
        chans = read_tsv(lay, chanPath[1], DataFrame)
    end

    if isempty(chanMetaPath)
        chansMeta = nothing
    elseif length(chanMetaPath) > 1
        @warn "Multiple files matching the channels metadata filename at $cwd. \
        Reading the first from the list." _id="EEG Channels"
        chansMeta = read_json(lay, chanMetaPath[1], TabularMeta)
    else
        chansMeta = read_json(lay, chanMetaPath[1], TabularMeta)
    end

    return EEGChannels(chans, chansMeta)
end

mutable struct EEGCoordsystem
    IntendedFor::Union{String, Vector{String}, Nothing}                         # optional
    EEGCoordinateSystem::Union{String, Nothing}                                 # required
    EEGCoordinateUnits::Union{String, Nothing}                                  # required
    EEGCoordinateSystemDescription::Union{String, Nothing}                      # recommended
    FiducialsDescription::Union{String, Nothing}                                # optional
    FiducialsCoordinates::Union{Dict{String, Vector{Number}}, Nothing}          # recommended
    FiducialsCoordinateSystem::Union{String, Nothing}                           # recommended
    FiducialsCoordinateUnits::Union{String, Nothing}                            # recommended
    FiducialsCoordinateSystemDescription::Union{String, Nothing}                # recommended
    AnatomicalLandmarkCoordinates::Union{Dict{String, Vector{Number}}, Nothing} # recommended
    AnatomicalLandmarkCoordinateSystem::Union{String, Nothing}                  # recommended
    AnatomicalLandmarkCoordinateUnits::Union{String, Nothing}                   # recommended
    AnatomicalLandmarkCoordinateSystemDescription::Union{String, Nothing}       # recommended
end

mutable struct EEGElectrodes
    data::Union{DataFrame, Nothing}
    metadata::Union{Dict{Symbol, TabularMeta}, Nothing}
    coordsystem::Union{EEGCoordsystem, Nothing}
end

function _get_eeg_electrodes(lay, cwd, sameFiles)
    # Check if there is a task specific set of files, if not, search for a general one
    elecPath = filter(endswith("_electrodes.tsv"), joinpath.(cwd, sameFiles))
    if isempty(elecPath)
        elecPath = filter(endswith("_electrodes.tsv"), readdir(cwd, join=true))
        isempty(elecPath) || push!(sameFiles, basename(elecPath[1]))
    end

    if isempty(elecPath)
        elecs = nothing
    elseif length(elecPath) > 1
        @warn "Multiple files matching the channels filename at $cwd. \
        Reading the first from the list." _id="EEG Channels"
        elecs = read_tsv(lay, elecPath[1], DataFrame)
    else
        elecs = read_tsv(lay, elecPath[1], DataFrame)
    end

    elecMetaPath = filter(endswith("_electrodes.json"), joinpath.(cwd, sameFiles))
    if isempty(elecMetaPath)
        elecMetaPath = filter(endswith("_electrodes.json"), readdir(cwd, join=true))
        isempty(elecMetaPath) || push!(sameFiles, basename(elecMetaPath[1]))
    end

    if isempty(elecMetaPath)
        elecsMeta = nothing
    elseif length(elecMetaPath) > 1
        @warn "Multiple files matching the channels metadata filename at $cwd. \
        Reading the first from the list." _id="EEG Channels"
        elecsMeta = read_json(lay, elecMetaPath[1], TabularMeta)
    else
        elecsMeta = read_json(lay, elecMetaPath[1], TabularMeta)
    end

    coordPath = filter(endswith("_coordsystem.json"), joinpath.(cwd, sameFiles))
    if isempty(coordPath)
        coordPath = filter(endswith("_coordsystem.json"), readdir(cwd, join=true))
        isempty(coordPath) || push!(sameFiles, basename(coordPath[1]))
    end

    if isempty(coordPath)
        coords = nothing
    elseif length(coordPath) > 1
        @warn "Multiple files matching the channels metadata filename at $cwd. \
        Reading the first from the list." _id="EEG Channels"
        coords = read_json(lay, coordPath[1], EEGCoordsystem)
    else
        coords = read_json(lay, coordPath[1], EEGCoordsystem)
    end
    
    return EEGElectrodes(elecs, elecsMeta, coords)
end

mutable struct EEG{T<:EEGFile} <: Modality
    Description::Union{EEGDescription, Nothing}
    Channels::EEGChannels
    Electrodes::EEGElectrodes
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
            @warn "Couldn't match files for $(join(element, "_")) to any known EEG datatype" _id="EEG"
            continue
        end

        # Parse the JSON sidecar
        description = _get_eeg_description(lay, cwd, sameFiles)

        # Parse the Channels file
        channels = _get_eeg_channels(lay, cwd, sameFiles)

        # Parse the Electrodes and Coordsystem files
        electrodes = _get_eeg_electrodes(lay, cwd, sameFiles)

        row["files"] = EEG{param}(description, channels, electrodes, path, sameFiles)

        # Check if subject label from file matches the path and remove the one from file
        _check_label(row, "participant_id", "sub")
        # Same check for session label if present in filename
        haskey(row, "ses") && _check_label(row, "session", "ses")

        push!(modalities, row)
    end
end

# Add new type to the parser list
parsers["eeg"] = EEG