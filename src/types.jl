mutable struct Source
    DOI::Union{String, Nothing}
    URL::Union{String, Nothing}
    Version::Union{String, Nothing}
end

mutable struct Container
    Tag::Union{String, Nothing}
    Type::Union{String, Nothing}
    URI::Union{String, Nothing}
end

mutable struct Generator
    Name::String
    Version::Union{String, Nothing}
    Description::Union{String, Nothing}
    CodeURL::Union{String, Nothing}
    Container::Union{Container, Nothing}
end

mutable struct DatasetLink
    URI::String
end

mutable struct Description
    Name::String
    BIDSVersion::String
    HEDVersion::Union{String, Vector{String}, Nothing}
    DatasetLinks::Union{Vector{DatasetLink}, Nothing}
    DatasetType::Union{String, Nothing}
    License::Union{String, Nothing}
    Authors::Union{Vector{String}, Nothing}
    Acknowledgments::Union{String, Nothing}
    HowToAcknowledge::Union{String, Nothing}
    Funding::Union{Vector{String}, Nothing}
    EthicsApprovals::Union{Vector{String}, Nothing}
    ReferencesAndLinks::Union{Vector{String}, Nothing}
    DatasetDOI::Union{String, Nothing}
    GeneratedBy::Union{Vector{Generator}, Nothing}
    SourceDatasets::Union{Vector{Source}, Nothing}
end

mutable struct TabularMeta
    LongName::Union{String, Nothing}
    Description::Union{String, Nothing}
    Levels::Union{SortedDict{String, String}, Nothing}
    Units::Union{String, Nothing}
    TermURL::Union{String, Nothing}
    HED::Union{Dict{String, String}, Nothing}
end

#=
Current version is not handling modality agnostic files:
- Phenotypic and assesment data
- Scans
- Sessions
- Code
=#
mutable struct Dataset
    Description::Description
    README::String
    CHANGES::Union{String, Nothing}
    LICENSE::Union{String, Nothing}
    Participants::Union{Dict, Nothing}
    ParticipantsInfo::Union{DataFrame, Nothing}
    ParticipantsMeta::Union{Dict, Nothing}
    Samples::Union{DataFrame, Nothing}
    SamplesMeta::Union{Dict, Nothing}
end

abstract type Modality end

struct EEG <: Modality end

function Dataset(dir::AbstractString)
    datasetPath = abspath(dir)

    descriptionPath = joinpath(datasetPath, "dataset_description.json")
    description = JSON3.read(descriptionPath, Description)

    # We might consider a more robust solution if more files have "README" in the name.
    readmeFiles = filter(startswith("README"), readdir(datasetPath))
    readmePath = joinpath(datasetPath, readmeFiles[1])
    readme = open(readmePath) do file
        read(file, String)
    end

    changesFiles = filter(startswith("CHANGES"), readdir(datasetPath))
    if !isempty(changesFiles)
        changesPath = joinpath(datasetPath, changesFiles[1])
        changes = open(changesPath) do file
            read(file, String)
        end
    else
        changes = nothing
    end

    licenseFiles = filter(startswith("LICENSE"), readdir(datasetPath))
    if !isempty(licenseFiles)
        licensePath = joinpath(datasetPath, licenseFiles[1])
        license = open(licensePath) do file
            read(file, String)
        end
    else
        license = nothing
    end

    subFolders = filter(startswith("sub-"), readdir(datasetPath))
    participants = Dict{String, Dict{String, Modality}}()


    participantsInfoPath = joinpath(dir, "participants.tsv")
    participantsInfo = isfile(participantsInfoPath) ? CSV.read(participantsInfoPath, delim="\t", DataFrame) : nothing
    participantsMetaPath = joinpath(dir, "participants.json")
    participantsMeta = isfile(participantsMetaPath) ? JSON3.read(participantsMetaPath, Dict{Symbol, TabularMeta}) : nothing

    samplesPath = joinpath(dir, "samples.tsv")
    samples = isfile(samplesPath) ? CSV.read(samplesPath, delim="\t", DataFrame) : nothing
    samplesMetaPath = joinpath(dir, "samples.json")
    samplesMeta = isfile(samplesMetaPath) ? JSON3.read(samplesMetaPath, Dict{Symbol, TabularMeta}) : nothing

    return Dataset(description, readme, changes, license, participants, participantsInfo, participantsMeta, samples, samplesMeta)
end