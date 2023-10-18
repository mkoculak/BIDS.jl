import Term: Term, @green, @red
import AbstractTrees: children, printnode

abstract type FBNode end

mutable struct File <: FBNode
    path::String
    read::Bool
    changed::Bool
end

mutable struct Folder <: FBNode
    path::String
    children::OrderedDict{String, Union{Folder, File}}
end

mutable struct Layout <: FBNode
    path::String
    children::OrderedDict{String, Union{Folder, File}}
    folder_count::Int64
    file_count::Int64
end

function Layout(dir::String; full=true)
    # Deal with trailing slashes
    dir = rstrip(dir, ['\\', '/'])
    path = abspath(dir)
    !isdir(path) && throw(ArgumentError("Path to the dataset is not correct."))
    
    root, folders, files = first(walkdir(path))
    # Filter hidden files and folders
    content = String[]
    push!(content, filter(x->!startswith(x, '.'), files)...)
    push!(content, filter(x->!startswith(x, '.'), folders)...)
    children = OrderedDict{String, Union{Folder, File}}()

    count = Dict(
    "folders" => 0,
    "files" => 0,
    )

    if !full
        return Layout(path, children, 0, 0)
    end

    for element in content
        elPath = joinpath(path, element)
        if isdir(elPath)
            children[element] = Folder(elPath, count)
        elseif isfile(elPath)
            children[element] = File(elPath, count)
        end
    end

    return Layout(path, children, count["folders"], count["files"])
end

function Folder(path::String, count::Dict)
    count["folders"] += 1
    name = basename(path)

    root, folders, files = first(walkdir(path))
    # Filter hidden files and folders
    content = String[]
    push!(content, filter(x->!startswith(x, '.'), folders)...)
    push!(content, filter(x->!startswith(x, '.'), files)...)
    children = OrderedDict{String, Union{Folder, File}}()

    for element in content
        elPath = joinpath(path, element)
        if isdir(elPath)
            children[element] = Folder(elPath, count)
        elseif isfile(elPath)
            children[element] = File(elPath, count)
        end
    end

    return Folder(path, children)
end

function File(path::String, count::Dict)
    count["files"] += 1
    return File(path, false, false)
end

Base.getindex(l::Layout, key::String) = l.children[key]
Base.getindex(f::Folder, key::String) = f.children[key]

children(f::File) = ()
children(f::Folder) = values(f.children)
children(l::Layout) = values(l.children)

function Base.show(io::IO, l::Layout)
    print(io, "BIDS Directory (path: $(l.path), folders: $(l.folder_count), files: $(l.file_count))")
end

function Base.show(io::IO, f::Folder)
    print(io, "BIDS Folder (path: $(f.path), \
    folders: $(sum(typeof.(values(f.children)) .== Folder)), \
    files: $(sum(typeof.(values(f.children)) .== File)))")
end

Base.show(io::IO, f::File) = print(io, "BIDS File (path: $(f.path))")

printnode(io::IO, l::Layout) = print(io, "📂 " * basename(l.path))
printnode(io::IO, f::Folder) = print(io, "📁 " * basename(f.path))

function printnode(io::IO, f::File)
    name = basename(f.path)
    if f.read
        if f.changed
            print(io, "📄 " * Term.@red name)
        else
            print(io, "📄 " * Term.@green name)
        end
    else
        print(io, "📄 " * Term.@white name)
    end
end

function browse(node::FBNode; print_node_function=printnode, maxdepth=1,
                indicate_truncation=false, prefix=" ", kw...)
    
    return Term.Trees.Tree(node; print_node_function=print_node_function,
        maxdepth=maxdepth, indicate_truncation=indicate_truncation, prefix=prefix, kw...)
end

function count_files(folder::Folder)
    count = Dict(
    "folders" => 0,
    "files" => 0,
    )

    count_files(folder, count)

    return count
end

function count_files(folder::Folder, count::Dict)
    for child in keys(folder.children)
        if typeof(folder[child]) == BIDS.Folder
            count["folders"] += 1
            count_files(folder[child], count)
        else
            count["files"] +=1
        end
    end
end