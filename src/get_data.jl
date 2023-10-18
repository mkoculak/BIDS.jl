get_data(dataset::Dataset, field::AbstractString) = get_data(dataset, Symbol(field))

function get_data(dataset::Dataset, field::Symbol)
    # Check if field is in the Dataset.
    if field in propertynames(dataset)
        if field in [:Participants, :Samples]
            f = getfield(dataset, field)
            if isnothing(f)
                return nothing
            else
                return getfield(f, :data)
            end
        else
            return getfield(dataset, field)
        end
    end

    # Check if field is in the Description
    field in propertynames(dataset.Description) && return getfield(dataset.Description, field)

    @warn "No data field $field found in the dataset."
end

_parse_selectors(selector::Any) = throw(ArgumentError("Cannot parse selector of type $(typeof(selector)), \
please provide a String or a Symbol."))
_parse_selectors(selector::Missing) = selector
_parse_selectors(selector::Integer) = [string(selector)]
_parse_selectors(selector::Symbol) = [string(selector)]
_parse_selectors(selectors::Vector{Symbol}) = string.(selectors)
_parse_selectors(selector::AbstractString) = [selector]
_parse_selectors(selectors::Vector{<:AbstractString}) = selectors
_parse_selectors(selector::AbstractPattern) = [selector]

function _get_mask(selectors, target)
    if ismissing(selectors)
        return map(x -> ismissing(x), target)
    else
        return map(x -> ismissing(x) ? 0 : any(occursin.(selectors, x)), target)
    end
end

function get_data(dataset::Dataset; sub="", ses="", type="", kwargs...)
    df = getfield(dataset, :Data)
    sub = _parse_selectors(sub)
    ses = _parse_selectors(ses)
    type = _parse_selectors(type)

    selector = _get_mask(sub, df.participant_id) .& _get_mask(ses, df.session) .& _get_mask(type, df.modality)

    # Use other kwargs as selectors if provided.
    # It has to match the column name, which in turn is taken from the filenames.
    for kw in kwargs 
        if hasproperty(df, first(kw))
            selector .&= _get_mask(_parse_selectors(last(kw)), df[!, first(kw)])
        end
    end

    return df[selector, :files]
end

get_metadata(dataset::Dataset, field::AbstractString) = get_metadata(dataset, Symbol(field))

function get_metadata(dataset::Dataset, field::Symbol)
    # Check if field is in the Dataset.
    if field in propertynames(dataset)
        if field in [:Participants, :Samples]
            f = getfield(dataset, field)
            if isnothing(f)
                return nothing
            else
                return getfield(f, :data)
            end
        else
            return getfield(dataset, field)
        end
    end

    # Check if field is in the Description
    field in propertynames(dataset.Description) && return getfield(dataset.Description, field)

    @warn "No data field $field found in the dataset."
end