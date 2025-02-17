"""
    Dataset

Main structure holding all the information related to a BIDS dataset. It contains all the
modality agnostic information as separate fields, `Data` field that holds all the modality 
specific information, `Layout` representing the file structure, and path to the dataset.

Where applicable, information is stored in custom structures named after the related BIDS 
entities. We try to extract as much information as possible from text-based files, while 
indexing all modality specific files as paths that one can pass to software tools that can
read them.

### Fields
Name | Type | Req. level | Description
:--- | :--- | :--------- | :----------
Path | `String` | Required | Path to the dataset
Layout | `Layout` | Required | File structure of the dataset
Description | `UN{Description}` | Required | Description of the dataset
README | `UN{String}` | Required | README file content
CHANGES | `UN{String}` | Optional | CHANGES file content
LICENSE | `UN{String}` | Optional | LICENSE file content
Participants | `UN{Participants}` | Recommended | Participants data
Data | `UN{DataFrame}` | Required | Modality specific data
Samples | `UN{Samples}` | Required | Samples data
Phenotypes | `UN{DataFrame}` | Optional | Phenotype data
Code | `UN{String}` | Optional | Code files content

`UN{T}` is an alias for `Union{Nothing, T}`.
"""
mutable struct Dataset
    Path::String
    Layout::Layout
    Description::UN{Description}    # required
    README::UN{String}              # required
    CHANGES::UN{String}             # optional
    LICENSE::UN{String}             # optional
    Participants::UN{Participants}  # recomended
    Data::UN{DataFrame}             # required
    Samples::UN{Samples}            # required if samples used in dataset
    Phenotypes::UN{DataFrame}       # optional
    Code::UN{String}                # optional
end

"""
    Dataset(dir::AbstractString, browser=true)

Create a BIDS dataset from the given directory.

### Arguments
- `dir::AbstractString`: Path to the dataset directory
- `browser::Bool=true`: Whether to map the whole file structure of the dataset

### Returns
- `dataset::Dataset`

While relying closely on the BIDS specification, function tries to extract as much information
as possible, even if it does not strictly follow the specification. In such cases, a warning is
logged that can be later inspected with `show_warnings()` function. However, if the discrepancy
cannot be easily resolved or is related to information required by the specification, an error
is thrown.
"""
function Dataset(dir::AbstractString, browser=true)
    # Prepare logging mechanism
    empty!(warnings)
    old_logger = global_logger(demux_loger);

    # Map folders and files of the dataset
    layout = Layout(dir; full=browser)

    # Parse dataset description (mandatory file)
    description = Description(layout)

    # Read the README (mandatory file)
    readme = _get_plaintext(layout, "README", true)

    # Read the CHANGES file if present
    # TODO: Parse CHANGES file according to the CPAN Changelog convention
    changes = _get_plaintext(layout, "CHANGES", true)

    # Read the LICENSE file if present
    license = _get_plaintext(layout, "LICENSE", false)

    # Read the participants data
    participants = _get_participants(layout)

    # Read the structure of participants' folders
    data = _get_data(layout, participants)

    # Read the samples data
    samples = _get_samples(layout)

    # Read the phenotype data, if present
    phenotypes = _get_phenotypes(layout)

    # Read sessions data, if present
    sessions = _get_sessions(layout)
    if !isnothing(sessions)
        participants.data = DataFrames.outerjoin(participants.data, sessions, on=:participant_id)
    end

    # Count files in code folder, if it exists
    code = _get_code(layout)

    # Return the original logger
    global_logger(old_logger);
    report_warnings()

    return Dataset(layout.path, layout, description, readme, changes, license, participants, 
                data, samples, phenotypes, code)
end


function Base.show(io::IO, dataset::Dataset)
    printstyled(io, "BIDS DATASET\n", bold=true, color=38)

    print_line(io, "Name", dataset.Description.Name)
    if isnothing(dataset.Participants)
        print_line(io, "Participants", string(length(unique(dataset.Data[:,:participant_id]))))
    else
        print_line(io, "Participants", string(DataFrames.nrow(dataset.Participants.data)))
    end
    print_line(io, "Sessions", string(DataFrames.nrow(unique(dataset.Data[!, [:participant_id, :session]]))))
    mods = unique(dataset.Data[:,:modality])
    print_line(io, "Modalities", "$(length(mods)) ($(join(mods, ", ")))")
    print_line(io, "Folders", string(dataset.Layout.folder_count))
    print_line(io, "Files", string(dataset.Layout.file_count))
    print_line(io, "Path", dataset.Path)
end

browse(dataset::Dataset; kwargs...) = browse(dataset.Layout; kwargs...)
