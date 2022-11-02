struct Path
    seq::LongDNA{4}
    dist::Int
end


struct PathTemplates
    paths::IdDict{Int64, Vector{Vector{Int64}}}
    len::Int # length without the PAM
    distance::Int
end


function remove_1_before_non_horizontal!(x::Vector{Int}, base::Vector{Int})
    x_not_in_base = (.!in.(x, Ref(base))) << 1
    x_not_in_base[end] = false
    deleteat!(x, x_not_in_base)
end


function remove_gap!(x::Vector{Int}, gap_idx::Int)
    deleteat!(x, x .== gap_idx)
end


"""
```
adj_matrix_of_guide(
    len::Int, d::Int; 
    mismatch_only::Bool = false)
```

Builds up a shortened version of the alignment graph.
Bases are numbered as: all guide bases (1:len) + Ending times
all the distance we want to extend to, afterwards we add numbering for 
Insertions, Gap and Mismatches - 3 for each distance.
Then for finding all possible alignment with distance 0, you would check
path from node 1 to node (guide length + 1). For distance 1, you would check
all paths from node 1 to (guide length + 1) * 2.

# Arguments
`len` - length of the sequence (e.g. guide)

`d` - Maximal distance on which to build the graph.

`mismatch_only`   -  Whether to skip insertions/deletions.

"""
function adj_matrix_of_guide(len::Int, d::Int; mismatch_only::Bool = false) 
    # notParent is a description for mismatch - it is a base that is not the base of parent node
    l_g = (len + 1) * (d + 1) # guide bases + Ending/Nothing/E - last position
    # + 1 below is last mm from last base to last base on next distance
    l_idm = l_g + (len * 3) * d #  all ins, del, mm - last position

    # fill up all connections
    # horizontal connections (between) guide bases
    adj = zeros(Bool, l_idm, l_idm)
    for di in 1:(d + 1)
        for i in 1:len
            adj[(len + 1) * (di - 1) + i, (len + 1) * (di - 1) + i + 1] = 1
        end
    end
    # vertical connections (between) guide bases - N/Gap/notParent - base on another level
    for di in 1:d
        for i in 1:len
            parent = (len + 1) * (di - 1) + i
            parent_d_next = (len + 1) * di + i
            n = l_g + len * (di - 1) * 3 + (i - 1) * 3 + 1

            if !mismatch_only
                # N
                adj[parent, n] = 1
                adj[n, parent_d_next] = 1

                # Gap
                adj[parent, n + 1] = 1
                adj[n + 1, parent_d_next + 1] = 1
            end

            # notParent
            adj[parent, n + 2] = 1
            adj[n + 2, parent_d_next + 1] = 1
        end
    end
    return adj
end


"""
```
build_PathTemplates(len::Int, d::Int; storagepath::String = "", mismatch_only::Bool = false)
```

Builds up a PathTemplates object. Stores 
shortened version of all possible paths within each distance `d`
mapped on the graph of all possible alignments of sequence of length
`len`. Then one can use `templates_to_sequences_extended` or 
`templates_to_sequences` and map guide sequence to all possible alignments quickly.

# Arguments
`len` - length of the sequence (e.g. guide - without PAM)

`d` - Maximal distance on which to build the graph.

`storagepath` - If not empty "", will save the object under given path.

`mismatch_only` - Whether to skip insertions/deletions.

"""
function build_PathTemplates(len::Int, d::Int; storagepath::String = "", mismatch_only::Bool = false)
    # path is mapped to these numbers, path numbers are
    # (len + end) * (dist  + 1) and
    # (Ins (N) + Gap + MM) * len * dist
    # and they should be mapped to
    # guide + not guide + N + Gap + remove last index as it is ending node
    # 1:20    21:40       41  42
    # 1:len   len+1:len*2 len*2 + 1, len*2 + 2, len*2 + 3

    adj = adj_matrix_of_guide(len, d; mismatch_only = mismatch_only)
    ngp = repeat([len * 2 + 1, len * 2 + 2, len * 2 + 3], len * d)
    # replace noParents (mismatches - not guide) with proper links to noParents
    for di in 1:d
        for i in 1:len
            ngp[((len) * (di - 1) * 3) + i * 3] = len + i 
        end
    end
    adj_map_to_guide = vcat(repeat(vcat(1:len, 0), d + 1), ngp)

    paths = IdDict{Int64, Vector{Vector{Int64}}}()
    gap_idx = len * 2 + 2
    is_seq_idx = collect(1:len)
    for di in 1:(d + 1)
        pd = path_enumeration(1, (len + 1) * di, adj)
        pd = map(x -> adj_map_to_guide[x.path[1:end-1]], pd)
        # this is to remove 1bp before insertion/mm/gap
        map(x -> remove_1_before_non_horizontal!(x, is_seq_idx), pd)
        map(x -> remove_gap!(x, gap_idx), pd)
        paths[di - 1] = pd
    end

    paths = PathTemplates(paths, len, d)
    if storagepath != ""
        save(paths, storagepath)
    end
    return paths 
end



"""
```
build_PathTemplates(motif::Motif; storagepath::String = "", mismatch_only::Bool = false)
```

Builds up a PathTemplates object. Stores 
shortened version of all possible paths for given `Motif`. 
Afterwards use `templates_to_sequences_extended` or 
`templates_to_sequences` and map guide sequence to all possible alignments quickly.

# Arguments
`motif` - Motif object.

`storagepath` - If not empty "", will save the object under given path.

`mismatch_only` - Whether to skip insertions/deletions.

"""
function build_PathTemplates(motif::Motif; storagepath::String = "", mismatch_only::Bool = false)
    len = length_noPAM(motif)
    d = motif.distance
    return build_PathTemplates(len, d; storagepath = storagepath, mismatch_only = mismatch_only)
end


"""
```
guide_to_template_format(guide::LongDNA{4})
```

Helper that allows you to create mapping vector for the Paths.
Then enumerating possible alignments becomes simple subsetting.

g_[Path_vector]
"""
function guide_to_template_format(guide::LongDNA{4})
    g_ = copy(guide)
    for (i, base) in enumerate(guide)
        if base == DNA_A
            not_base = DNA_B
        elseif base == DNA_C 
            not_base = DNA_D
        elseif base == DNA_T
            not_base = DNA_V
        elseif base == DNA_G 
            not_base = DNA_H
        end
        push!(g_, not_base)
    end
    push!(g_, DNA_N)
    push!(g_, DNA_Gap)
    return collect(g_)
end



"""
```
templates_to_sequences_extended(
    guide::LongDNA{4}, 
    template::PathTemplates;
    dist::Int = template.distance)
```

Uses PathTemplates object - `template` to map
all possible alignments for given `guide` within distance `dist`.
This method expands sequence to the maximal alignment length:
length of the guide + length of the distance. All returned sequences
will be of the same length. The advantage of that is that outputs are unique.

# Arguments
`guide` - guide sequence, without PAM.

`template` - PathTemplates object build for your specific guide queries.

`dist` - Maximal distance on which to return the possible alignments.

# Return

Returns a Vector{Set{LongDNA{4}}} where distance 0 is located at index 1,
distance 1 all possible alignments are located at distance 2 and so on...

"""
function templates_to_sequences_extended(
    guide::LongDNA{4}, 
    template::PathTemplates;
    dist::Int = template.distance)
    len = template.len + template.distance

    if length(guide) != template.len
        throw("Wrong guide length.")
    end

    g_ = guide_to_template_format(guide)

    ps = Vector{Set{LongDNA{4}}}()
    for di in 0:dist
        push!(ps, Set(ThreadsX.mapreduce(
            x -> expand_ambiguous(
                LongDNA{4}(g_[x]) * repeat(dna"N", len - length(x))), 
            vcat,
            template.paths[di]; init = Vector{LongDNA{4}}())))
    end
    # if a sequence can exist in lower distance it belongs there rather than higher distance
    # dist 0 is at position 1 in ps, d1 at 2
    for di in 1:dist
        ps[di + 1] = setdiff(ps[di + 1], union(ps[1:di]...))
    end
    return ps
end


"""
```
templates_to_sequences(
    guide::LongDNA{4}, 
    template::PathTemplates;
    dist::Int = template.distance)
```

Uses PathTemplates object - `template` to map
all possible alignments for given `guide` within distance `dist`.
This method does not expand sequences to the maximal alignment length
as opposed to `templates_to_sequences_extended`. This means some sequences might 
seem redundant, for example:
```
For guide "AAA" and Motif("test"), distance 2:

sequence distance 
AAA      0 
AA       1
AAAA     1
     ...
```

# Arguments
`guide` - guide sequence, without PAM.

`template` - PathTemplates object build for your specific guide queries.

`dist` - Maximal distance on which to return the possible alignments.

# Return

Returns a Vector{Path} sorted by the distance, from 0 to `dist`.

"""
function templates_to_sequences(
    guide::LongDNA{4}, 
    template::PathTemplates;
    dist::Int = template.distance)

    if length(guide) != template.len
        throw("Wrong guide length.")
    end

    g_ = guide_to_template_format(guide)

    ps = Vector{Path}()
    for di in 0:dist
        seq = ThreadsX.mapreduce(
            x -> expand_ambiguous(LongDNA{4}(g_[x])), 
            vcat,
            template.paths[di]; init = Vector{LongDNA{4}}())
        seq = ThreadsX.collect(Set(seq))
        append!(ps, ThreadsX.map(x -> Path(x, di), seq))
    end

    # this will return simply seqeuences which can be repeats, D0 in front
    return ThreadsX.sort!(ps, by = p -> (p.dist, p.seq))
end


function templates_to_sequences(
    guide::LongDNA{4}, 
    template::PathTemplates,
    motif::Motif;
    dist::Int = template.distance)

    if length_noPAM(motif) != template.len
        throw("Length of the motif is not the same as the template!")
    end

    if length(guide) != template.len
        throw("Wrong guide length.")
    end

    g_ = guide_to_template_format(guide)

    ps = Vector{Path}()
    for di in 0:dist
        seq = ThreadsX.mapreduce(
            x -> expand_ambiguous(
                appendPAM_forward(LongDNA{4}(g_[x]), motif)), 
            vcat,
            template.paths[di]; init = Vector{LongDNA{4}}())
        seq = ThreadsX.collect(Set(seq))
        append!(ps, ThreadsX.map(x -> Path(x, di), seq))
    end

    # this will return simply sequences which can be repeats, D0 in front
    return ThreadsX.sort!(ps, by = p -> (p.dist, p.seq))
end











