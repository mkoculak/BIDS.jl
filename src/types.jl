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
    Path::String
    Description::Description
    README::String
    CHANGES::Union{String, Nothing}
    LICENSE::Union{String, Nothing}
    Participants::Union{DataFrame, Nothing}
    ParticipantsMeta::Union{Dict, Nothing}
    ParticipantsData::Union{DataFrame, Nothing}
    Samples::Union{DataFrame, Nothing}
    SamplesMeta::Union{Dict, Nothing}
end

function _dir_contents(absPath::String)
    objects = readdir(absPath)
    folders = filter(x -> isdir(joinpath(absPath, x)), objects)
    files = filter(x -> isfile(joinpath(absPath, x)), objects)
    return folders, files
end

function _get_subjects(absPath::String)
    folders, files = _dir_contents(absPath)
    return filter(startswith("sub-"), folders)
end

function _get_sub_structure(datasetPath::String, subject::String, modalities::Vector{NamedTuple}; session="")
    folders, files = _dir_contents(joinpath(datasetPath, subject, session))

    sessions = filter(startswith("ses-"), folders)
    if isempty(sessions)
        map(mod -> push!(modalities, (sub=subject, ses=session, mod=mod)), folders)
    else
        for session in sessions
            _get_sub_structure(datasetPath,subject, modalities, session=session)
        end
    end
end

function _get_modalities(datasetPath::String, subjects::Vector{String})
    modalities = NamedTuple[]
    for subject in subjects
        _get_sub_structure(datasetPath, subject, modalities)
    end
    return DataFrame(modalities)
end

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

    subjects = _get_subjects(datasetPath)
    participantsData = _get_modalities(datasetPath, subjects)

    participantsPath = joinpath(dir, "participants.tsv")
    participants = isfile(participantsPath) ? CSV.read(participantsPath, delim="\t", DataFrame) : nothing
    participantsMetaPath = joinpath(dir, "participants.json")
    participantsMeta = isfile(participantsMetaPath) ? JSON3.read(participantsMetaPath, Dict{Symbol, TabularMeta}) : nothing

    samplesPath = joinpath(dir, "samples.tsv")
    samples = isfile(samplesPath) ? CSV.read(samplesPath, delim="\t", DataFrame) : nothing
    samplesMetaPath = joinpath(dir, "samples.json")
    samplesMeta = isfile(samplesMetaPath) ? JSON3.read(samplesMetaPath, Dict{Symbol, TabularMeta}) : nothing

    return Dataset(datasetPath, description, readme, changes, license, participants, participantsMeta, participantsData, samples, samplesMeta)
end