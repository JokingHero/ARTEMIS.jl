struct DictDB
    dict::IdDict
    dbi::DBInfo
end


function build_guide_dict(dbi::DBInfo, max_count::Int, guide_type::Type{T}) where T <: Union{UInt64, UInt128}
    max_count_type = smallestutype(unsigned(max_count))
    guides = Vector{guide_type}()
    gatherofftargets!(guides, dbi) # we ignore ambig
    guides = sort(guides)
    guides, counts = ranges(guides)
    counts = convert.(max_count_type, min.(length.(counts), max_count))
    return IdDict{guide_type, max_count_type}(zip(guides, counts))
end


function build_dictDB(
    name::String, 
    genomepath::String, 
    motif::Motif,
    storagedir::String;
    max_count::Int = 10)

    if motif.distance != 0 || motif.ambig_max != 0
        @info "Distance and ambig_max enforced to 0."
        motif = setdist(motif, 0)
        motif = setambig(motif, 0)
    end
    dbi = DBInfo(genomepath, name, motif)

    # first we measure how many unique guides there are
    @info "Building Dictionary..."
    dict = build_guide_dict(dbi, max_count, UInt128)

    db = DictDB(dict, dbi)
    save(db, joinpath(storagedir, "dictDB.bin"))
    @info "Finished constructing dictDB in " * storagedir
    @info "Database size is:" *
        "\n length -> " * string(length(db.dict)) *
        "\n consuming: " * string(round((filesize(joinpath(storagedir, "dictDB.bin")) * 1e-6); digits = 3)) * 
        " mb of disk space."
    return storagedir
end


function search_dictDB(
    storagedir::String,
    guides::Vector{LongDNA{4}},
    dist::Int = 1)

    if any(isambig.(guides))
        throw("Ambiguous bases are not allowed in guide queries.")
    end

    sdb = load(joinpath(storagedir, "dictDB.bin"))
    guides_ = copy(guides)
    # reverse guides so that PAM is always on the left
    if sdb.dbi.motif.extends5
        guides_ = reverse.(guides_)
    end

    # TODO check that seq is in line with motif
    res = zeros(Int, length(guides_), (dist + 1) * 3 - 2)
    for (i, s) in enumerate(guides_)
        res[i, 1] += get(sdb.dict, convert(UInt128, s), 0) # 0 distance
        for d in 1:dist
            norm_d, border_d = comb_of_d(string(s), d)
            norm_d_res = ThreadsX.sum(get(sdb.dict, convert(UInt128, LongDNA{4}(sd)), 0) for sd in norm_d)
            border_d_res = ThreadsX.sum(get(sdb.dict, convert(UInt128, LongDNA{4}(sd)), 0) for sd in border_d)
            res[i, d + 1] = norm_d_res + border_d_res
            res[i, dist + d + 1] = norm_d_res
            res[i, dist * 2 + d + 1] = border_d_res
        end
    end

    res = DataFrame(res, :auto)
    col_d = [Symbol("D$i") for i in 0:dist]
    all_col_d = vcat(col_d, [Symbol("DN$i") for i in 1:dist], [Symbol("DB$i") for i in 1:dist])
    rename!(res, all_col_d)
    res.guide = guides
    sort!(res, col_d)
    return res
end