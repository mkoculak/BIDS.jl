mutable struct Dataset
    Path::String
    Layout::Layout
    Description::Description
    README::String
    CHANGES::Union{String, Nothing}
    LICENSE::Union{String, Nothing}
    Participants::Union{Participants, Nothing}
    Data::Union{DataFrame, Nothing}
    Samples::Union{Samples, Nothing}
    Phenotypes::Union{DataFrame, Nothing}
    Code::Union{String, Nothing}
end

function Dataset(dir::AbstractString, browser=true)
    # Map folders and files of the dataset
    layout = Layout(dir, browser)

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

    # Read the metadata for samples table
    # samplesMeta = _get_samples_meta(layout)

    # Read the phenotype data, if present
    phenotypes = _get_phenotypes(layout)

    # Read sessions data, if present
    sessions = _get_sessions(layout)
    if !isnothing(sessions)
        participants.data = DataFrames.outerjoin(participants.data, sessions, on=:participant_id)
    end

    # Count files in code folder, if it exists
    code = _get_code(layout)

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

