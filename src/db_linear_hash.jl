"
Final SuffixHashDB unit that contains all guides from
all chromosomes that start with the `prefix` and their locations.
Also contains Nbp hash of the potential OTs.
"
struct SuffixHashDB
    prefix::LongDNA{4}
    suffix::Vector{LongDNA{4}}
    suffix_loci_idx::Vector{LociRange}
    loci::Vector{Loc}
    hash::Vector{UInt32}
end


struct LinearHashDB
    dbi::DBInfo
    paths::Matrix{Int}
    paths_distances::Vector{Int}
    hash_len::Int
    prefixes::Set{LongDNA{4}}
end


"""
```
name::String,
    genomepath::String,
    motif::Motif,
    storage_dir::String,
    prefix_len::Int = 7,
    hash_len::Int = min(length_noPAM(motif) - motif.distance, 16))
```

Prepare linearHashDB index for future searches using `search_linearHashDB`.

Will return a path to the database location, same as `storage_dir`.
If interested with searches within distance 4, preferably use `prefix_len` of 8 or 9.
You can also play with `hash_len` parameter, but keeping it at 16 should be close to optimal.

# Arguments
`name` - Your preferred name for this index for easier identification.

`genomepath` - Path to the genome file, it can either be fasta or 2bit file. In case of fasta
               also prepare fasta index file with ".fai" extension.

`motif`   - Motif defines what kind of gRNA to search for.

`storage_dir`  - Folder path to the where index will be saved with name `linearDB.bin` and many prefix files.

`prefix_len`  - Size of the prefix by which off-targets are indexed. Prefix of 8 or larger will be the fastest,
                however it will also result in large number of files.

`hash_len` - Length of the hash in bp. At maximum 16.

# Examples
```julia-repl
$(make_example_doc("linearHashDB"))
```
"""
function build_linearHashDB(
    name::String,
    genomepath::String,
    motif::Motif,
    storage_dir::String,
    prefix_len::Int = 7,
    hash_len::Int = min(length_noPAM(motif) - motif.distance, 16))

    if prefix_len <= motif.distance
        throw("prefix_len $prefix_len is <= " * string(motif.distance))
    end

    if hash_len > 16
        throw("hash_len $hash_len is more than 16")
    end

    dbi = DBInfo(genomepath, name, motif)

    # step 1
    @info "Step 1: Searching chromosomes."
    # For each chromsome paralelized we build database
    ref = open(dbi.gi.filepath, "r")
    reader = dbi.gi.is_fa ? FASTA.Reader(ref, index = dbi.gi.filepath * ".fai") : TwoBit.Reader(ref)
    # Don't paralelize here as you can likely run out of memory (chromosomes are large)
    mkpath(storage_dir)
    prefixes = Base.mapreduce(
        x -> do_linear_chrom(x, getchromseq(dbi.gi.is_fa, reader[x]), dbi, prefix_len, storage_dir), 
        union,
        dbi.gi.chrom)
    close(ref)
    prefixes = Set(prefixes)
    GC.gc() # free memory

    # step 2
    @info "Step 2: Constructing per prefix db."
    # Iterate over all prefixes and merge different chromosomes
    ThreadsX.map(prefixes) do prefix
        guides = Vector{LongDNA{4}}()
        loci = Vector{Loc}()
        for chrom in dbi.gi.chrom
            p = joinpath(storage_dir, string(prefix), string(prefix) * "_" * chrom * ".bin")
            if ispath(p)
                pdb = load(p)
                append!(guides, pdb.suffix)
                append!(loci, pdb.loci)
            end
        end
        rm(joinpath(storage_dir, string(prefix)), recursive = true)
        (guides, loci_range, loci) = unique_guides(guides, loci)
        # hash part guides = prefix + guides
        hashes = ThreadsX.map(guides) do guide
            convert(UInt32, (prefix * guide)[1:hash_len])
        end
        sdb = SuffixHashDB(prefix, guides, loci_range, loci, hashes)
        save(sdb, joinpath(storage_dir, string(prefix) * ".bin"))
    end

    @info "Step 3: Constructing Paths for hashes"
    mpt = build_PathTemplates(motif; restrict_to_len = hash_len, withPAM = false)
    paths = mpt.paths[:, 1:hash_len]
    not_dups = map(!, BitVector(nonunique(DataFrame(paths, :auto)))) # how can there be no duplicated function?!
    linDB = LinearHashDB(dbi, paths[not_dups, :], mpt.distances[not_dups], hash_len, prefixes)
    save(linDB, joinpath(storage_dir, "linearHashDB.bin"))
    @info "Finished constructing linearHashDB in " * storage_dir
    return storage_dir
end


function search_prefix_hash(
    prefix::LongDNA{4},
    paths_set::Vector{Set{UInt32}},
    dist::Int,
    dbi::DBInfo,
    detail::String,
    guides::Vector{LongDNA{4}},
    storage_dir::String)

    # prefix alignment against all the guides
    suffix_len = length_noPAM(dbi.motif) + dbi.motif.distance - length(prefix)
    prefix_aln = Base.map(g -> prefix_align(g, prefix, suffix_len, dist), guides)
    isfinal = Base.map(x -> x.isfinal, prefix_aln)

    if all(isfinal)
        return
    end

    detail_path = joinpath(detail, "detail_" * string(prefix) * ".csv")
    detail_file = open(detail_path, "w")

    # if any of the guides requires further alignment 
    # load the SuffixDB and iterate
    sdb = load(joinpath(storage_dir, string(prefix) * ".bin"))
    for i in 1:length(guides)
        if !isfinal[i]
            for (j, suffix) in enumerate(sdb.suffix)
                if sdb.hash[j] in paths_set[i]
                    suffix_aln = suffix_align(suffix, prefix_aln[i])
                    if suffix_aln.dist <= dist
                        sl_idx = sdb.suffix_loci_idx[j]
                        offtargets = sdb.loci[sl_idx.start:sl_idx.stop]
                        if dbi.motif.extends5
                            guide_stranded = reverse(prefix_aln[i].guide)
                            aln_guide = reverse(suffix_aln.guide)
                            aln_ref = reverse(suffix_aln.ref)
                        else
                            guide_stranded = prefix_aln[i].guide
                            aln_guide = suffix_aln.guide
                            aln_ref = suffix_aln.ref
                        end
                        noloc = string(guide_stranded) * "," * aln_guide * "," * 
                                aln_ref * "," * string(suffix_aln.dist) * ","
                        for offt in offtargets
                            write(detail_file, noloc * decode(offt, dbi) * "\n")
                        end
                    end
                end
            end
        end
    end

    close(detail_file)
    return
end


"""
```
search_linearHashDB(
    storage_dir::String, 
    guides::Vector{LongDNA{4}}, 
    output_file::String;
    distance::Int = 3)
```

Find all off-targets for `guides` within distance of `dist` using linearHashDB located at `storage_dir`.

Assumes your guides do not contain PAM, and are all in the same direction as 
you would order from the lab e.g.:

```
5' - ...ACGTCATCG NGG - 3'  -> will be input: ...ACGTCATCG
     guide        PAM
    
3' - CCN GGGCATGCT... - 5'  -> will be input: ...AGCATGCCC
     PAM guide
```

# Arguments

`output_file` - Path and name for the output file, this will be comma separated table, therefore `.csv` extension is preferred. 
This search will create intermediate files which will have same name as `output_file`, but with a sequence prefix. Final file
will contain all those intermediate files.

`distance` - Defines maximum levenshtein distance (insertions, deletions, mismatches) for 
which off-targets are considered.

# Examples
```julia-repl
$(make_example_doc("linearHashDB"))
```
"""
function search_linearHashDB(
    storage_dir::String, 
    guides::Vector{LongDNA{4}}, 
    output_file::String;
    distance::Int = 3)

    ldb = load(joinpath(storage_dir, "linearHashDB.bin"))
    prefixes = collect(ldb.prefixes)
    if distance > length(first(prefixes)) || distance > ldb.dbi.motif.distance
        error("For this database maximum distance is " * 
              string(min(ldb.dbi.motif.distance, length(first(prefixes)))))
    end

    guides_ = copy(guides)
    # reverse guides so that PAM is always on the left
    if ldb.dbi.motif.extends5
        guides_ = reverse.(guides_)
    end

    
    paths = ldb.paths[ldb.paths_distances .<= distance, :]
    paths_set = ThreadsX.map(copy(guides_)) do g
        guides_formated = guide_to_template_format(g; alphabet = ALPHABET_TWOBIT)
        ot_uint32 = guides_formated[paths]
        ot_uint32 = map(ARTEMIS.asUInt32, eachrow(ot_uint32))
        # BinaryFuseFilter{UInt32}(unique(ot_uint64)) # very space efficient!!!
        return Set(ot_uint32)
    end

    mkpath(dirname(output_file))
    ThreadsX.map(p -> search_prefix_hash(p, paths_set, distance, ldb.dbi, dirname(output_file), guides_, storage_dir), prefixes)
    
    cleanup_detail(output_file)
    return
end


"""
```
search_linearHashDB_with_es(
    storage_dir::String, 
    guides::Vector{LongDNA{4}}, 
    output_file::String;
    distance::Int = 3,
    early_stopping::Vector{Int} = Int.(floor.(exp.(0:distance))))
```

Find all off-targets for `guides` within distance of `dist` using linearHashDB located at `storage_dir`.
Uses early stopping to stop searching when a guide passes a limit on number of off-targets. This method does not 
keep track of the off-target locations and does not filter overlapping off-targets, therefore it might hit the 
early stopping condition a little earlier than intended.

Assumes your guides do not contain PAM, and are all in the same direction as 
you would order from the lab e.g.:

```
5' - ...ACGTCATCG NGG - 3'  -> will be input: ...ACGTCATCG
     guide        PAM
    
3' - CCN GGGCATGCT... - 5'  -> will be input: ...AGCATGCCC
     PAM guide
```

# Arguments

`output_file` - Path and name for the output file, this will be comma separated table, therefore `.csv` extension is preferred. 
This search will create intermediate files which will have same name as `output_file`, but with a sequence prefix. Final file
will contain all those intermediate files.

`distance` - Defines maximum levenshtein distance (insertions, deletions, mismatches) for 
which off-targets are considered.

`early_stopping` - Integer vector. Early stopping condition. For example for distance 2, we need vector with 3 values e.g. [1, 1, 5].
Which means we will search with "up to 1 offtargets within distance 0", "up to 1 offtargets within distance 1"...

# Examples
```julia-repl
$(make_example_doc("linearHashDB"; search = "linearHashDB_with_es"))
```
"""
function search_linearHashDB_with_es(
    storage_dir::String, 
    guides::Vector{LongDNA{4}}, 
    output_file::String;
    distance::Int = 3,
    early_stopping::Vector{Int} = Int.(floor.(exp.(0:distance))))

    if length(early_stopping) != (distance + 1)
        error("Specify one early stopping condition for a each distance, starting from distance 0.")
    end

    ldb = load(joinpath(storage_dir, "linearHashDB.bin"))
    prefixes = collect(ldb.prefixes)
    if distance > length(first(prefixes)) || distance > ldb.dbi.motif.distance
        error("For this database maximum distance is " * 
              string(min(ldb.dbi.motif.distance, length(first(prefixes)))))
    end

    guides_ = copy(guides)
    # reverse guides so that PAM is always on the left
    if ldb.dbi.motif.extends5
        guides_ = reverse.(guides_)
    end

    paths = ldb.paths[ldb.paths_distances .<= distance, :]
    paths_set = ThreadsX.map(copy(guides_)) do g
        guides_formated = ARTEMIS.guide_to_template_format(g; alphabet = ARTEMIS.ALPHABET_TWOBIT)
        ot_uint32 = guides_formated[paths]
        ot_uint32 = map(ARTEMIS.asUInt32, eachrow(ot_uint32))
        return Set(ot_uint32)
    end

    mkpath(dirname(output_file))
    is_es = falses(length(guides_)) # which guides are early stopped already
    es_accumulator = zeros(Int64, length(guides_), length(early_stopping))
    all_offt_lock = ReentrantLock()

    # align first all the guides against all the prefixes
    suffix_len = length_noPAM(ldb.dbi.motif) + ldb.dbi.motif.distance - length(prefixes[1])
    prefix_aln = ThreadsX.map(prefix -> Base.map(g -> ARTEMIS.prefix_align(g, prefix, suffix_len, distance), guides_), prefixes)
    prefix_filter = ThreadsX.map(x -> !all(Base.map(y -> y.isfinal, x)), prefix_aln)
    prefixes = prefixes[prefix_filter]
    prefix_aln = prefix_aln[prefix_filter]
    prefixes_order = sortperm(ThreadsX.map(x -> sum(Base.map(y -> y.isfinal, x)), prefix_aln))
    prefixes = prefixes[prefixes_order]
    prefix_aln = prefix_aln[prefixes_order]

    # ThreadsX.map(p -> search_prefix_hash(p, paths_set, distance, ldb.dbi, dirname(output_file), guides_, storage_dir), prefixes)
    Threads.@threads for p in 1:length(prefixes) # iterate over ordered prefixes that are not filtered out

        detail_path = joinpath(dirname(output_file), "detail_" * string(prefixes[p]) * ".csv")
        detail_file = open(detail_path, "w")

        # if any of the guides requires further alignment 
        # load the SuffixDB and iterate
        sdb = load(joinpath(storage_dir, string(prefixes[p]) * ".bin"))
        for i in 1:length(guides_)
            if !prefix_aln[p][i].isfinal & !is_es[i]
                for (j, suffix) in enumerate(sdb.suffix)
                    if sdb.hash[j] in paths_set[i]
                        suffix_aln = suffix_align(suffix, prefix_aln[p][i])
                        if suffix_aln.dist <= distance
                            sl_idx = sdb.suffix_loci_idx[j]
                            offtargets = sdb.loci[sl_idx.start:sl_idx.stop]
                            if ldb.dbi.motif.extends5
                                guide_stranded = reverse(prefix_aln[p][i].guide)
                                aln_guide = reverse(suffix_aln.guide)
                                aln_ref = reverse(suffix_aln.ref)
                            else
                                guide_stranded = prefix_aln[p][i].guide
                                aln_guide = suffix_aln.guide
                                aln_ref = suffix_aln.ref
                            end
                            noloc = string(guide_stranded) * "," * aln_guide * "," * 
                                    aln_ref * "," * string(suffix_aln.dist) * ","
                            lock(all_offt_lock) do
                                es_accumulator[i, suffix_aln.dist + 1] += length(offtargets)
                                if es_accumulator[i, suffix_aln.dist + 1] >= early_stopping[suffix_aln.dist + 1]
                                    is_es[i] = true
                                end
                            end
                            for offt in offtargets
                                write(detail_file, noloc * decode(offt, ldb.dbi) * "\n")
                            end
                        end
                    end
                end
            end
        end

        close(detail_file)
    end
    
    cleanup_detail(output_file)
    return
end