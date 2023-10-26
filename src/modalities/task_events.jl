mutable struct Events
    data::Union{DataFrame, Nothing}
    metadata::Union{Dict{Symbol, TabularMeta}, Nothing}
end

function _get_events(lay, cwd, sameFiles)
    eventsPath = filter(endswith("_events.tsv"), joinpath.(cwd, sameFiles))

    if isempty(eventsPath)
        events = nothing
    elseif length(eventsPath) > 1
        @warn "Multiple files matching the events filename at $cwd. \
        Reading the first from the list." _id="Events"
        events = read_tsv(lay, eventsPath[1], DataFrame)
    else
        events = read_tsv(lay, eventsPath[1], DataFrame)
    end

    eventsMetaPath = filter(endswith("_electrodes.json"), joinpath.(cwd, sameFiles))

    if isempty(eventsMetaPath)
        eventsMeta = nothing
    elseif length(eventsMetaPath) > 1
        @warn "Multiple files matching the events metadata filename at $cwd. \
        Reading the first from the list." _id="Events"
        eventsMeta = read_json(lay, eventsMetaPath[1], TabularMeta)
    else
        eventsMeta = read_json(lay, eventsMetaPath[1], TabularMeta)
    end

    return Events(events, eventsMeta)
end