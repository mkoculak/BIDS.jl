const UN{T} = Union{Nothing, T}
const UNV{T} = Union{Nothing, T, AbstractVector{T}}

mutable struct Container
    Tag::UN{String}
    Type::UN{String}
    URI::UN{String}
end

mutable struct Generator
    Name::UN{String}
    Version::UN{String}
    Description::UN{String}
    CodeURL::UN{String}
    Container::UN{Container}
end

mutable struct Source
    DOI::UN{String}
    URL::UN{String}
    Version::UN{String}
end

"""
    Description

Object containing information from the dataset_description.json file.

### Fields
Name | Type | Req. level | Description
:--- | :--- | :--------- | :----------
Name | `String` | Required | Name of the dataset
BIDSVersion | `String` | Required | BIDS version used to create the dataset
HEDVersion | `UNV{String}` | Recommended | HED version used in the dataset
DatasetLinks | `UN{Dict{String, String}}` | Required | Links to the dataset
DatasetType | `UN{String}` | Recommended | Type of the dataset
License | `UN{String}` | Recommended | License type
Authors | `UN{AbstractVector{String}}` | Recommended | List of authors
Acknowledgements | `UN{String}` | Optional | Acknowledgement text
HowToAcknowledge | `UN{String}` | Optional | Instructions how to acknowledge the dataset
Funding | `UNV{String}` | Optional | Funding sources
EthicsApprovals | `UN{AV{String}}` | Optional | Ethics approvals
ReferencesAndLinks | `UN{AV{String}}` | Optional | References and links
DatasetDOI | `UN{String}` | Optional | DOI of the dataset
GeneratedBy | `UN{AV{Generator}}` | Recommended | Software used to generate the dataset
SourceDatasets | `UN{AV{Source}}` | Recommended | Source datasets

Where `UN{T}` is an alias for `Union{Nothing, T}`
and `UNV{T}` is an alias for `Union{Nothing, T, AbstractVector{T}}`.
"""
mutable struct Description
    Name::String                                   # required
    BIDSVersion::String                            # required
    HEDVersion::UNV{String}                        # recomended
    DatasetLinks::UN{Dict{String, String}}         # required if URIs are used
    DatasetType::UN{String}                        # recomended
    License::UN{String}                            # recomended
    Authors::UN{AbstractVector{String}}            # recomended
    Acknowledgements::UN{String}                   # optional
    HowToAcknowledge::UN{String}                   # optional
    Funding::UNV{String}                           # optional
    EthicsApprovals::UN{AbstractVector{String}}    # optional
    ReferencesAndLinks::UN{AbstractVector{String}} # optional
    DatasetDOI::UN{String}                         # optional
    GeneratedBy::UN{AbstractVector{Generator}}     # recomended
    SourceDatasets::UN{AbstractVector{Source}}     # recomended
end

# Check if fields in file match their specifications
function _check_values(fid::IO, specification)
    seek(fid, 0)
    raw = JSON3.read(fid)

    specKeys = fieldnames(specification)
    specTypes = fieldtypes(specification)
    unexpected = String[]

    for key in keys(raw)
        if (key in specKeys)
            idx = findfirst(isequal(key), specKeys)
            if !(typeof(raw[key]) <: specTypes[idx])
                push!(unexpected, String(key))
            end
        end
    end

    return unexpected
end

function Description(lay::Layout)
    datasetPath = lay.path
    descriptionPath = joinpath(datasetPath, "dataset_description.json")

    # Missing file
    if !isfile(descriptionPath)
        @warn "Required file dataset_description.json not found in folder: $(datasetPath)" _id="description"
        return nothing
    end

    description = open(descriptionPath) do fid
        try
            #description = JSON3.read(fid, Description)
            description = read_json(lay, descriptionPath, fid, Description)
            
            # Check if file has some fields outside of BIDS scope
            seek(fid, 0)
            orgFile = JSON3.read(fid)
            unsupported = filter(x -> !(x in fieldnames(Description)), keys(orgFile))
            if !isempty(unsupported)
                @warn """File dataset_description.json contains keys unsupported by the current version of BIDS($BIDSVersion): \
                $(join(unsupported, ", "))""" _id="description"
            end

            return description
        
        catch err
            # Parsing failure
            if isa(err, ArgumentError)
                unexpected = _check_values(fid, Description)

                if isempty(unexpected)
                    throw(ErrorException("""Failed to parse dataset_description.json file.
                    \t Try `JSON3.read(dataset_description.json, BIDS.Description)` to see details."""))
                else
                    throw(ArgumentError("""File dataset_description.json contains fields not matching BIDS specification (v. $BIDSVersion): 
                    \t $(join(unexpected, ", "))"""))
                end
            
            # Missing some required fields
            elseif isa(err, MethodError)
                required = [:Name, :BIDSVersion]
                seek(fid, 0)
                verbs = JSON3.read(fid)
                missingFields = filter(x -> !(x in keys(verbs)), required)
                throw(ArgumentError("File dataset_description.json is missing required fields: $(join(missingFields, ", "))"))
            
            # All other errors are passed through
            else
                rethrow(err)
            end
        end
    end

    return description
end

function Base.show(io::IO, description::Description; leadSize=40)
    printstyled(io, "DESCRIPTION\n", bold=true, color=38)

    for field in fieldnames(Description)
        content = getfield(description, field)
        if typeof(content) <: AbstractArray
            content = repr(content)
        elseif isnothing(content)
            continue
        end
        etc = length(content) > leadSize ? "..." : ""
        label = lpad(String(field), 2+textwidth(String(field)))
        lead = first(content, leadSize)
        content = lpad(lead, 21 + textwidth(lead) - textwidth(label))
        println(io, "$label:$content$etc")
    end
end

# HANDLING OF PLAINTEXT FILES

function _get_plaintext(lay::Layout, filename::String, missWarn::Bool)
    datasetPath = lay.path
    # Get all the files that have README in their name
    textFiles = filter(contains(filename), readdir(datasetPath))

    if isempty(textFiles)
        missWarn && @warn "No $filename file was found in the root directory." _id=filename
        return "" #nothing
    elseif length(textFiles) > 1
        @warn "More than one $filename file in the root directory. Reading the first found: $(textFiles[1])" _id=filename
    end

    textPath = joinpath(datasetPath, textFiles[1])
    text = open(textPath) do file
        read(file, String)
    end
    mark_read!(lay, textPath)
    
    return text
end

# HANDLING OF TABULAR DATA

"""
    TableMetadata

Generic structure for metadata about a column in a tabular file.

### Fields
Name | Type | Req. level | Description
:--- | :--- | :--------- | :----------
LongName | `UN{String}` | Optional | Full name of the variable
Description | `UN{String}` | Recommended | Free-form natural language description
Levels | `UN{SortedDict{String, String}}` | Recommended | Mapping for categorical variables
Units | `UN{String}` | Recommended | Units of measurement
Delimeter | `UN{String}` | Optional | Delimeter used in the file
TermURL | `UN{String}` | Recommended | URL to a formal definition of the type of data
HED | `UN{Dict{String, String}}` | Optional | Hierarchical Event Descriptor information
Derivative | `UN{Bool}` | - | Whether the variable is a derivative
"""
mutable struct TableMetadata
    LongName::UN{String}                    # optional
    Description::UN{String}                 # recommended
    Levels::UN{SortedDict{String, String}}  # recommended
    Units::UN{String}                       # recommended
    Delimeter::UN{String}                   # optional
    TermURL::UN{String}                     # recommended
    HED::UN{Dict{String, String}}           # optional
    Derivative::UN{Bool}                    # -
end

"""
    Participants

Object containing information from the participants.tsv file.

### Fields
Name | Type | Description
:--- | :--- | :----------
data | `DataFrame` | Tabular data from the file
metadata | `UN{Dict{Symbol, TableMetadata}}` | Metadata from the associated JSON file

Where `UN{T}` is an alias for `Union{Nothing, T}`
"""
mutable struct Participants
    data::DataFrame
    metadata::UN{Dict{Symbol, TableMetadata}}
end

function _get_participants_meta(lay::Layout)
    participantsMetaPath = joinpath(lay.path, "participants.json")

    if isfile(participantsMetaPath)
        participantsMeta = read_json(lay, participantsMetaPath, Dict{Symbol, TableMetadata})
    else
        participantsMeta = nothing
    end

    return participantsMeta
end

function _get_participants(lay::Layout)
    participantsPath = joinpath(lay.path, "participants.tsv")

    if isfile(participantsPath)
        participants = CSV.read(participantsPath, delim="\t", DataFrame)
        # Check if the file contains participant_id column
        if !in("participant_id", names(participants))
            throw(ArgumentError("File participants.tsv does not contain the participant_id column."))
        end
        sort!(participants, :participant_id)
        mark_read!(lay, participantsPath)

        metadata = _get_participants_meta(lay)

        return Participants(participants, metadata)
    else
        return nothing
    end
end

"""
    Scans

Object containing information from the scans.tsv file.

### Fields
Name | Type | Description
:--- | :--- | :----------
data | `DataFrame` | Tabular data from the file
metadata | `UN{Dict{Symbol, TableMetadata}}` | Metadata from the associated JSON file

Where `UN{T}` is an alias for `Union{Nothing, T}`
"""
mutable struct Scans
    data::DataFrame
    metadata::UN{Dict{Symbol, TableMetadata}}
end

Base.show(io::IO, scans::Scans) = print(io, "$(DataFrames.nrow(scans.data)) timing(s)")

function _get_scans(lay, path, files)
    scans = filter(endswith.("scans.tsv"), files)
    if !isempty(scans)
        scansPath = joinpath(path, scans[1])
        recordings = read_tsv(lay, scansPath, DataFrame)
        # Try to read metadata from the same folder
        metaFile = splitext(scans[1])[1] * ".json"
        if isfile(joinpath(path, metaFile))
            metadata = read_json(lay, joinpath(path, metaFile), Dict{Symbol, TableMetadata})
        else
            # Try to read a scans.json file shared between sessions
            upPath = dirname(path)
            upDir = readdir(dirname(path))
            metaFile = filter(endswith.("scans.json"), upDir)
            if !isempty(metaFile)
                metadata = read_json(lay, joinpath(upPath, metaFile[1]), Dict{Symbol, TableMetadata})
            else
                metadata = nothing
            end
        end

        return Scans(recordings, metadata)
    else
        return string()
    end
end

function _get_sub_structure!(lay::Layout, subject::String, modalities::Vector{Dict}; session="")
    path = joinpath(lay.path, subject, session)

    files = readdir(path)
    folders = filter(x -> isdir(joinpath(path, x)), files)
    sessions = filter(startswith("ses-"), folders)

    if isempty(sessions)
        modalityRow = Dict{String, Any}()
        modalityRow["participant_id"] = subject
        modalityRow["session"] = session
        modalityRow["scans"] = _get_scans(lay, path, files)
        
        for mod in folders
            modalityRow["modality"] = mod
            _parse_mod_files!(lay, path, mod, modalities, modalityRow)
        end

    else
        for session in sessions
            _get_sub_structure!(lay, subject, modalities, session=session)
        end
    end
end

function _get_modalities(lay::Layout, subjects::Vector{String})
    modalities = Dict[]
    for subject in subjects
        _get_sub_structure!(lay, subject, modalities)
    end

    # Merge all rows into one dataframe
    modFrame = DataFrame(dictrowtable(modalities))

    # Replace all missings with empty strings
    mapcols!(x -> replace(x, missing => string()), modFrame)

    # Reorder columns
    select!(modFrame, :participant_id, :session, :scans, Not([:participant_id, :session, :scans, :files]), :files)
    return modFrame
end

function _get_data(lay::Layout, participants::UN{Participants})
    datasetPath = lay.path
    objects = readdir(datasetPath)
    folders = filter(x -> isdir(joinpath(datasetPath, x)), objects)
    parti = filter(contains("sub-"), folders)

    data = _get_modalities(lay, parti)

    # Check if the participants.tsv file contains the same labels as there are subfolders
    if !isnothing(participants)
        partFile = unique(participants.data[!, :participant_id])
        partDir = unique(data[!, :participant_id])
    else
        partFile = partDir = String[]
    end
    
    if !issetequal(partFile, partDir)
        fileMore = setdiff(partFile, partDir)
        dirMore = setdiff(partDir, partFile)
        if !isempty(fileMore)
            @warn "File participants.tsv contains entries without a subfolder: $(join(fileMore, ", "))" _id="participants"
        end
        if !isempty(dirMore)
            @warn "There are subfolders not included as participants.tsv entries: $(join(dirMore, ", "))" _id="participants"
        end
    end

    return data
end

"""
    Samples

Object containing information from the samples.tsv file.

### Fields
Name | Type | Description
:--- | :--- | :----------
data | `DataFrame` | Tabular data from the file
metadata | `UN{Dict{Symbol, TableMetadata}}` | Metadata from the associated JSON file

Where `UN{T}` is an alias for `Union{Nothing, T}`
"""
mutable struct Samples
    data::DataFrame
    metadata::UN{Dict{Symbol, TableMetadata}}
end

function _get_samples_meta(lay::Layout)

    samplesMetaPath = joinpath(lay.path, "samples.json")
    if isfile(samplesMetaPath)
        samplesMeta = read_json(lay, samplesMetaPath, Dict{Symbol, TableMetadata})
    else
        samplesMeta = nothing
    end

    return samplesMeta
end

function _get_samples(lay::Layout)
    samplesPath = joinpath(lay.path, "samples.tsv")

    if isfile(samplesPath)
        samples = read_tsv(lay, samplesPath, DataFrame)
        metadata = _get_samples_meta(lay)
        return Samples(samples, metadata)
    else
        return nothing
    end
end

mutable struct Phenotype
    data::DataFrame
    metadata::UN{TableMetadata}
end

function _parse_phenotype_files(lay, file, fileRoot, root, session)
    filePath = joinpath(fileRoot, file)
    name, ext = splitext(file)

    # Search for metadata in current folder and top phenotype folder
    if isfile(joinpath(fileRoot, name * ".json"))
        metaPath = joinpath(fileRoot, name * ".json")
    elseif isfile(joinpath(root, name * ".json"))
        metaPath = joinpath(root, name * ".json")
    else
        metaPath = ""
    end

    phenotype = read_tsv(lay, filePath, DataFrame)
    if isempty(metaPath)
        metadata = nothing
    else
        metadata = read_json(lay, metaPath, TableMetadata)
    end

    return (name=name, session=session, phenotype=Phenotype(phenotype, metadata))
end

function _get_phenotype_files(lay, path)
    phenotypes = NamedTuple[]

    dirFiles = walkdir(path)

    root, folders, rootFiles = take!(dirFiles)

    for folder in folders 
        fileRoot, _, files = take!(dirFiles)
        phenoFiles = filter(contains(".tsv"), files)

        for file in phenoFiles
            push!(phenotypes, _parse_phenotype_files(lay, file, fileRoot, root, folder))
        end
    end

    rootPhenoFiles = filter(contains(".tsv"), rootFiles)
    for file in rootPhenoFiles
        push!(phenotypes, _parse_phenotype_files(lay, file, root, root, ""))
    end

    return phenotypes
end

function _get_phenotypes(lay::Layout)
    phenoPath = joinpath(lay.path, "phenotype")

    if isdir(phenoPath)
        phenotypes= _get_phenotype_files(lay, phenoPath)
        phenoFrame = DataFrame(phenotypes)
    else
        phenoFrame = nothing
    end

    return phenoFrame
end

"""
    Sessions

Object containing information from the *_sessions.tsv file.

### Fields
Name | Type | Description
:--- | :--- | :----------
data | `DataFrame` | Tabular data from the file
metadata | `UN{Dict{Symbol, TableMetadata}}` | Metadata from the associated JSON file

Where `UN{T}` is an alias for `Union{Nothing, T}`
"""
mutable struct Sessions
    data::DataFrame
    metadata::UN{Dict{Symbol, TableMetadata}}
end

function _get_sessions(lay::Layout)
    objects = readdir(lay.path)
    folders = filter(x -> isdir(joinpath(lay.path, x)), objects)
    subFolders = filter(contains("sub-"), folders)

    sessions = NamedTuple[]

    for subjectFolder in subFolders
        subPath = joinpath(lay.path, subjectFolder)
        subFiles = readdir(subPath, join=true)
        sessFile = filter(contains("_sessions.tsv"), subFiles)
        
        if !isempty(sessFile)
            session = read_tsv(lay, sessFile[1], DataFrame)

            metaFile = splitext(sessFile[1])[1] * ".json"
            if isfile(metaFile)
                metadata = read_json(lay, metaFile, Dict{Symbol, TableMetadata})
            else
                metadata = nothing
            end

            push!(sessions, (participant_id=subjectFolder, sessions=Sessions(session, metadata)))
        end
    end

    if isempty(sessions)
        return nothing
    else
        return DataFrame(sessions)
    end
end

# HANDLING OF CODE DATA

function _get_code(lay::Layout)
    if haskey(lay.children, "code")
        file_count = count_files(lay["code"])
        code = "$(file_count["folders"]) subfolder(s) and $(file_count["files"]) file(s)"
    else
        code = nothing
    end
end