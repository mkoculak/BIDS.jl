"""
Prints a label with description aligned to specified positions.
"""
function print_line(io::IO, label::String, content::String; 
                    labelStart=2, leadStart=20, leadLength=40, labelEnd=":", sepChar=' ')

    etc = length(content) > leadLength ? "..." : ""
    label *= labelEnd
    label = lpad(String(label), labelStart+textwidth(String(label)))
    label = rpad(label, leadStart-1, sepChar)
    lead = " " * first(content, leadLength)
    println(io, "$label$lead$etc")
end

function mark_read!(lay, path)
    # Exit if no folders/files in Layout
    iszero(lay.folder_count) && return nothing
    dirpath = lay.path
    filepath = chopprefix(path, dirpath)
    filepath = strip(filepath, ['\\', '/'])
    parts = splitpath(filepath)
    result = lay
    
    for elem in parts
        result = result[elem]
    end
    result.read = true
end

read_json(lay, path, obj) = read_json(lay, path, path, obj)

function read_json(lay, path, fid, obj)
    object = JSON3.read(fid, obj)
    mark_read!(lay, path)
    return object
end

function read_tsv(lay, path, obj)
    object = CSV.read(path, obj)
    mark_read!(lay, path)
    return object
end

# Logging aggregate to manage warnings during reading datasets due to specification violation

const warnings = Dict{String, Vector{String}}()

function show_warnings()
    return warnings
end

function report_warnings()
    if !isempty(warnings)
        warningNum = sum(map(length, values(warnings)))
        @warn "Encountered $warningNum warning(s) during dataset load. \
        Inspect them with show_warnings()."
    end
end

warning_logger  = TransformerLogger(NullLogger()) do log
    if haskey(warnings, log.id)
        push!(warnings[log.id], log.message)
    else
        warnings[log.id] = [log.message]
    end
    return log
end

warning_filter = EarlyFilteredLogger(warning_logger) do args
    return args.level == Warn
end

other_filter = EarlyFilteredLogger(global_logger()) do args
    return args.level != Warn
end

demux_loger = TeeLogger(warning_filter, other_filter)

# In case of error inside warning logging
default_logger = Base.current_logger();

reset_logger() = global_logger(default_logger);