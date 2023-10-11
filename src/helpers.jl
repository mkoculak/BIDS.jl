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