get_data(dataset::Dataset, field::AbstractString) = get_data(dataset, Symbol(field))

function get_data(dataset::Dataset, field::Symbol)
    # Check if field is in the Dataset.
    field in propertynames(dataset) && return getfield(dataset, field)

    # Check if field is in the Description
    field in propertynames(dataset.Description) && return getfield(dataset.Description, field)

    @warn "No data $field found in the dataset."
end

_parse_selectors(selector::Symbol) = [string(selector)]
_parse_selectors(selectors::Vector{Symbol}) = string.(selectors)
_parse_selectors(selector::AbstractString) = [selector]
_parse_selectors(selectors::Vector{<:AbstractString}) = selectors
_parse_selectors(selector::AbstractPattern) = [selector]

function _get_mask(selectors, target)
    return map(x -> any(occursin.(selectors, x)), target)
end

function get_data(dataset::Dataset; sub="", ses="", type="")
    df = getfield(dataset, :Data)
    sub = _parse_selectors(sub)
    ses = _parse_selectors(ses)
    type = _parse_selectors(type)

    selector = _get_mask(sub, df.participant_id) .& _get_mask(ses, df.session) .& _get_mask(type, df.modality)

    return df[selector, :files]
end