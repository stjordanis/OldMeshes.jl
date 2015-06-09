export exportStl,
       exportBinaryStl,
       importBinarySTL,
       importAsciiSTL

import Base.writemime

function exportStl(msh::Mesh, fn::String)
    exportStl(msh, open(fn, "w"))
end

function exportStl(msh::Mesh, str::IO, closeAfterwards::Bool=true)
    vts = msh.vertices
    fcs = msh.faces
    nV = size(vts,1)
    nF = size(fcs,1)

    # write the header
    write(str,"solid vcg\n")

    # write the data
    for i = 1:nF
        f = fcs[i]
        n = [0,0,0] # TODO: properly compute normal(f)
        @printf str "  facet normal %e %e %e\n" n[1] n[2] n[3]
        write(str,"    outer loop\n")
        v = vts[f.v1]
        @printf str "      vertex  %e %e %e\n" v[1] v[2] v[3]

        v = vts[f.v2]
        @printf str "      vertex  %e %e %e\n" v[1] v[2] v[3]

        v = vts[f.v3]
        @printf str "      vertex  %e %e %e\n" v[1] v[2] v[3]

        write(str,"    endloop\n")
        write(str,"  endfacet\n")
    end

    write(str,"endsolid vcg\n")
    if closeAfterwards
        close(str)
    end
end

function exportBinaryStl(msh::Mesh, fn::String)
    exportBinaryStl(msh, open(fn, "w"))
end

function exportBinaryStl(msh, str::IO, closeAfterwards::Bool=true)
    # Implementation made according to https://en.wikipedia.org/wiki/STL_%28file_format%29#Binary_STL
    vts = msh.vertices
    fcs = msh.faces
    nF = size(fcs,1)

    for i in 1:80 # write empty header
        write(str,0x00)
    end

    write(str, @compat UInt32(nF)) # write triangle count
    for i = 1:nF
        f = fcs[i]
        n = Float32[0,0,0] # TODO: properly compute normal(f)
        for i=1:3; write(str, n[i]); end # write normal

        for v in [f.v1, f.v2, f.v3]
            for j = 1:3
                write(str, @compat Float32(vts[v][j])) # write vertex coordinates
            end
        end
        write(str,0x0000) # write two empty Uint8
    end

    if closeAfterwards
        close(str)
    end
end

function writemime(io::IO, ::MIME"model/stl+ascii", msh::Mesh)
    exportSTL(msh, io)
end


function importBinarySTL(file::String)
    fn = open(file,"r")
    mesh = importBinarySTL(fn)
    close(fn)
    return mesh
end

function importBinarySTL(file::IO;read_header=false)
    #Binary STL
    #https://en.wikipedia.org/wiki/STL_%28file_format%29#Binary_STL

    binarySTLvertex(file) = Vertex((@compat Float64(read(file, Float32))),
                                   (@compat Float64(read(file, Float32))),
                                   (@compat Float64(read(file, Float32))))

    vts = Vertex[]
    fcs = Face{Int}[]

    if !read_header
        readbytes(file, 80) # throw out header
    end
    read(file, Uint32) # throwout triangle count

    vert_count = 0
    vert_idx = [0,0,0]
    while !eof(file)
        normal = binarySTLvertex(file)
        for i = 1:3
            vertex = binarySTLvertex(file)
            push!(vts, vertex)
            vert_count += 1
            vert_idx[i] = vert_count
        end
        skip(file, 2) # throwout 16bit attribute
        push!(fcs, Face{Int}(vert_idx...))
    end

    return Mesh{Vertex, Face{Int}}(vts, fcs)
end

function importAsciiSTL(file::String)
    fn = open(file,"r")
    mesh = importAsciiSTL(fn)
    close(fn)
    return mesh
end

function importAsciiSTL(file::IO)
    #ASCII STL
    #https://en.wikipedia.org/wiki/STL_%28file_format%29#ASCII_STL

    vts = Vertex[]
    fcs = Face{Int}[]

    vert_count = 0
    vert_idx = [0,0,0]
    while !eof(file)
        line = split(lowercase(readline(file)))
        if !isempty(line) && line[1] == "facet"
            normal = Vertex([parse(Float64, x) for x in line[3:5]]...)
            readline(file) # Throw away outerloop
            for i = 1:3
                vertex = Vertex([parse(Float64, x) for x in split(readline(file))[2:4]]...)
                push!(vts, vertex)
                vert_count += 1
                vert_idx[i] = vert_count
            end
            readline(file) # throwout endloop
            readline(file) # throwout endfacet
            push!(fcs, Face{Int}(vert_idx...))
        end
    end

    return Mesh{Vertex, Face{Int}}(vts, fcs)
end