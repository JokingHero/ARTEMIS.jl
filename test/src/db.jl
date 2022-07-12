using Test

using CRISPRofftargetHunter
using BioSequences
using CSV
using DataFrames

## SET WD when debugging
# cd("test")

## CRISPRitz compare functions - we test with up to 4 distance
function asguide(x::String)
    x = x[1:(length(x) - 3)]
    x = replace.(x, "-" => "")
    @assert length(x) == 20
    return x
end

function countspaces(x)
    return length(findall("-", x))
end

function ldb_start(pos, rrna_len, czdna_spac, strand)
    start = Vector{Int}()
    for i in 1:length(pos)
        if strand[i] == "+"
            i_start = pos[i] + rrna_len[i] - czdna_spac[i]
        else
            i_start = pos[i] + 1
        end
        push!(start, i_start)
    end
    return start
end

function rows_not_in(len::Int, rows_in::Vector{Int})
    all_rows = collect(1:len)
    rows_in_ = sort(unique(rows_in))
    if len == length(rows_in_)
        return []
    end
    deleteat!(all_rows, rows_in_)
    return all_rows
end


@testset "databases" begin
    genome = joinpath(dirname(pathof(CRISPRofftargetHunter)), "..", 
        "test", "sample_data", "genome", "semirandom.fa")
    guides_s = Set(readlines("./sample_data/crispritz_results/guides.txt"))
    guides = LongDNA{4}.(guides_s)
    tdir = tempname()
    mkpath(tdir)
    # guide ACTCAATCATGTTTCCCGTC is on the border - depending on the motif definition
    # it can/can't be found by different methods

    # make and run default vcfDB
    vcf_path = joinpath(tdir, "vcfDB")
    vcf = joinpath(dirname(pathof(CRISPRofftargetHunter)), "..", 
        "test", "sample_data", "artificial.vcf")
    mkpath(vcf_path)
    build_vcfDB(
        "samirandom", genome, vcf,
        Motif("Cas9"; distance = 1, ambig_max = 0),
        vcf_path)
    vcf_res = search_vcfDB(vcf_path, guides)

    # put into proper test later! TODO
    fmi_path = joinpath(tdir, "fmiDB")
    mkdir(fmi_path)
    fmidbpath = build_fmiDB(genome, fmi_path)
    pamdbpath = joinpath(fmi_path, "pamDB.bin")
    build_pamDB(fmi_path, Motif("Cas9"; distance = 3, ambig_max = 0); storagedir = pamdbpath)
    pamDB_res = search_pamDB(fmi_path, genome, pamdbpath, guides; detail = "", distance = 3)
    template = CRISPRofftargetHunter.build_motifTemplates(Motif("Cas9"; distance = 2, ambig_max = 0))
    fmi_patterns = search_fmiDB_patterns(fmidbpath, "", template, guides; distance = 2)

    @testset "vcfDB result is same as in saved file" begin
        ar_file = joinpath(dirname(pathof(CRISPRofftargetHunter)), "..", 
            "test", "sample_data", "artificial_results.csv")
        ar = DataFrame(CSV.File(ar_file))
        @test nrow(vcf_res) == length(guides)
        @test all(vcf_res.guide .== guides)
        @test all(Matrix(vcf_res[:, 1:2]) == Matrix(ar[:, 1:2]))
    end

    # make and run default linearDB
    ldb_path = joinpath(tdir, "linearDB")
    mkpath(ldb_path)
    build_linearDB("samirandom", genome, Motif("Cas9"), ldb_path, 7)
    detail_path = joinpath(ldb_path, "detail.csv")
    ldb_res = search_linearDB(ldb_path, guides, 3; detail = detail_path)
    ldb = DataFrame(CSV.File(detail_path))

    @testset "linearDB vs fmidx" begin
        dist = 2
        fmidb_path = joinpath(tdir, "fmiDB")
        mkpath(fmidb_path)

        motif_cas9 = Motif("Cas9")
        motif_cas9 = CRISPRofftargetHunter.setdist(motif_cas9, dist)

        template = CRISPRofftargetHunter.build_motifTemplates(motif_cas9)
        fmidbdir = build_fmiDB(genome, fmidb_path)

        fmidb_res = search_fmiDB_patterns(
            fmidbdir, genome, template, guides; distance = dist)

        @test nrow(fmidb_res) == length(guides)
        @test all(fmidb_res.guide .== guides)
        @test all(fmidb_res.guide .== guides)
        ldb_res2 = Matrix(ldb_res)
        fmidb_res2 = Matrix(fmidb_res)
        for i in 1:length(guides)
            compare = fmidb_res2[i, 1:3] .<= ldb_res2[i, 1:3]
            @test all(compare)
            if !all(compare)
                @info "Failed at guideS $i " * string(guides[i])
                @info "linearDB result: " * string(ldb_res2[i, :])
                @info "fmi result: " * string(fmidb_res2[i, :])
            end
        end
    end

    # make and run default dictDB
    ddb_path = joinpath(tdir, "dictDB")
    mkpath(ddb_path)
    build_dictDB(
        "samirandom", genome, 
        Motif("Cas9"; distance = 0, ambig_max = 0),
        ddb_path)
    ddb_res = search_dictDB(ddb_path, guides)

    # make and run default binDB
    bdb_path = joinpath(tdir, "binDB")
    mkpath(bdb_path)
    build_binDB(
        "samirandom", genome, 
        Motif("Cas9"; distance = 0, ambig_max = 0), 
        bdb_path)
    bdb_res = search_binDB(bdb_path, guides, false)

    # make and run default hashDB
    hdb_path = joinpath(tdir, "hashDB")
    mkpath(hdb_path)
    build_hashDB(
        "samirandom", genome, 
        Motif("Cas9"; distance = 1, ambig_max = 0), 
        hdb_path)
    hdb_res = search_hashDB(hdb_path, guides, false)

    # hashDB but with ambig
    hdb_path2 = joinpath(tdir, "hashDBambig")
    mkpath(hdb_path2)
    build_hashDB(
        "samirandom", genome, 
        Motif("Cas9"; distance = 1, ambig_max = 1), 
        hdb_path2)
    hdb_res2 = search_hashDB(hdb_path2, guides, false)

    len_noPAM = CRISPRofftargetHunter.length_noPAM(Motif("Cas9"))

    @testset "linearDB against CRISPRitz" begin
        ## Files
        cz_file = "./sample_data/crispritz_results/guides.output.targets.txt"
        cz = DataFrame(CSV.File(cz_file))
        cz = cz[cz.Total .<= 3, :]
        cz.guide = asguide.(String.(cz.crRNA))
        cz.start = ldb_start(cz.Position, length.(cz.crRNA), countspaces.(cz.DNA), cz.Direction)

        # list all alignments that are in linearDB and not in crizpritz output
        for g in guides_s
            czg = cz[cz.guide .== g, :]
            ldbg = ldb[ldb.guide .== g, :]

            isfound_in_czg = Vector{Int}() # indexes of rows of ldbg that are found in czg
            isfound_in_ldbg = Vector{Int}() # indexes of rows of czg that are found in ldbg
            for j in 1:nrow(ldbg)
                issame = (czg.Total .== ldbg.distance[j]) .&
                    (czg.Direction .== ldbg.strand[j]) .&
                    (czg.start .== ldbg.start[j]) .&
                    (czg.Chromosome .== ldbg.chromosome[j])
                if any(issame)
                    j_idx = findall(issame)
                    j_idx = j_idx[1]
                    push!(isfound_in_czg, j)
                    isfound_in_ldbg = vcat(isfound_in_ldbg, findall(
                        (czg.start .== czg.start[j_idx]) .&
                        (czg.Chromosome .== czg.Chromosome[j_idx]) .&
                        (czg.Direction .== czg.Direction[j_idx])))
                end
            end

            ldbg = ldbg[rows_not_in(nrow(ldbg), isfound_in_czg), :]
            czg = czg[rows_not_in(nrow(czg), isfound_in_ldbg), :]

            # crispritz can't handle anything too close to the telomeres NNN
            ldbg = ldbg[ldbg.start .> 125, :]

            # test that all guides are found in crispritz
            @test nrow(ldbg) <= 0
            if nrow(ldbg) > 0
                @info "Failed ldbg finding $g"
                @info "$ldbg"
            end

            # test that all guides are found in linear database
            @test nrow(czg) <= 0
            if nrow(czg) > 0
                @info "Failed cz finding $g"
                @info "$czg"
            end
        end
    end


    @testset "linearDB vs binDB" begin
        @test nrow(bdb_res) == length(guides)
        @test all(bdb_res.guide .== guides)
        @test all(ldb_res.guide .== guides)
        ldb_res2 = Matrix(ldb_res[:, 1:2])
        bdb_res2 = Matrix(bdb_res[:, 1:2])
        for i in 1:length(guides)
            compare = ldb_res2[i, :] .<= bdb_res2[i, :]
            @test all(compare)
            if !all(compare)
                @info "Failed at guideS $i " * string(guides[i])
                @info "linearDB result: " * string(ldb_res2[i, :])
                @info "binhDB result: " * string(bdb_res2[i, :])
            end
        end
    end


    @testset "linearDB vs hashDB" begin
        @test nrow(hdb_res) == length(guides)
        @test all(hdb_res.guide .== guides)
        @test all(ldb_res.guide .== guides)
        ldb_res2 = Matrix(ldb_res[:, 1:2])
        hdb_res2 = Matrix(hdb_res[:, 1:2])
        for i in 1:length(guides)
            compare = ldb_res2[i, :] .<= hdb_res2[i, :]
            @test all(compare)
            if !all(compare)
                @info "Failed at guideS $i " * string(guides[i])
                @info "linearDB result: " * string(ldb_res2[i, :])
                @info "sketchDB result: " * string(hdb_res2[i, :])
            end
        end
    end


    @testset "binDB vs dictDB" begin
        @test nrow(bdb_res) == nrow(ddb_res)
        @test all(bdb_res.guide .== guides)
        @test all(ddb_res.guide .== guides)
        ddb_res2 = Matrix(ddb_res)
        bdb_res2 = Matrix(bdb_res)
        for i in 1:length(guides)
            compare = ddb_res2[i, 1:2] .<= bdb_res2[i, 1:2]
            @test all(compare)
            if !all(compare)
                @info "Failed at guideS $i " * string(guides[i])
                @info "dictDB result: " * string(ddb_res2[i, :])
                @info "binDB result: " * string(bdb_res2[i, :])
            end
        end
        
        # Now check complete dictionary vs sketch
        dDB = CRISPRofftargetHunter.load(joinpath(ddb_path, "dictDB.bin"))
        bDB = CRISPRofftargetHunter.load(joinpath(bdb_path, "binDB.bin"))
        conflict = 0
        error = Vector{Int}()
        len_noPAM = CRISPRofftargetHunter.length_noPAM(dDB.dbi.motif) + dDB.dbi.motif.distance
        for (key, value) in dDB.dict
            key = LongDNA{4}(key, len_noPAM)
            if iscertain(key)
                svalue = CRISPRofftargetHunter.estimate(bDB, key, false)
                @test value <= svalue
                if svalue != value
                    conflict += 1
                    push!(error, svalue - value)
                end
            end
        end
        true_error_rate = conflict / length(dDB.dict)
        @info "True error rate is: $true_error_rate"
        if length(error) > 0
            @info "Maximum error: " * string(maximum(error))
        end
    end

    
    @testset "hashDB vs dictDB" begin
        @test nrow(hdb_res) == nrow(ddb_res)
        @test all(hdb_res.guide .== guides)
        @test all(ddb_res.guide .== guides)
        ddb_res2 = Matrix(ddb_res)
        hdb_res2 = Matrix(hdb_res)
        for i in 1:length(guides)
            compare = ddb_res2[i, 1:2] .<= hdb_res2[i, 1:2]
            # TODO fix this bug
            # @test all(compare)
            if !all(compare)
                @info "Failed at guideS $i " * string(guides[i])
                @info "dictDB result: " * string(ddb_res2[i, :])
                @info "hashDB result: " * string(hdb_res2[i, :])
            end
        end
        
        # TODO fixme
        # Now check complete dictionary vs hashDB - never underestimate
        #dDB = CRISPRofftargetHunter.load(joinpath(ddb_path, "dictDB.bin"))
        #bDB = CRISPRofftargetHunter.load(joinpath(hdb_path, "hashDB.bin"))
        #len_noPAM = CRISPRofftargetHunter.length_noPAM(dDB.dbi.motif) + dDB.dbi.motif.distance
        #for (key, value) in dDB.dict
        #    key = LongDNA{4}(key, len_noPAM) # all same length - check with D0
        #    if iscertain(key)
        #        # right false, means it can never underestimate
        #        svalue = CRISPRofftargetHunter.get_count_idx(bDB.bins_d0, convert(UInt64, key), false)
        #       @test value <= svalue
        #    end
        #end
    end

    
    @testset "linearDB vs treeDB" begin
        tdb_path = joinpath(tdir, "treeDB")
        mkpath(tdb_path)
        build_treeDB("samirandom", genome, Motif("Cas9"), tdb_path, 7)
        detail_path = joinpath(tdb_path, "detail.csv")

        for d in 1:3
            tdb_res = search_treeDB(tdb_path, guides, d; detail = detail_path)
            tdb = DataFrame(CSV.File(detail_path))
            @test nrow(tdb_res) == length(guides)
            @test all(ldb_res.guide .== guides)
            @test all(tdb_res.guide .== guides)
            @test Matrix(ldb_res[:, 1:(d + 1)]) == Matrix(tdb_res[:, 1:(d + 1)])
        end

        # for final distance check also detail output
        tdb = DataFrame(CSV.File(detail_path))
        failed = antijoin(ldb, tdb, on = [:guide, :distance, :chromosome, :start, :strand])
        @test nrow(failed) == 0
    end


    @testset "linearDB vs motifDB" begin
        mdb_path = joinpath(tdir, "motifDB")
        mkpath(mdb_path)
        build_motifDB("samirandom", genome, Motif("Cas9"), mdb_path, 7)
        detail_path = joinpath(mdb_path, "detail.csv")

        for d in 1:3
            mdb_res = search_motifDB(mdb_path, guides, d; detail = detail_path)
            mdb = DataFrame(CSV.File(detail_path))
            @test nrow(mdb_res) == length(guides)
            @test all(ldb_res.guide .== guides)
            @test all(mdb_res.guide .== guides)
            @test Matrix(ldb_res[:, 1:(d + 1)]) == Matrix(mdb_res[:, 1:(d + 1)])
        end

        # for final distance check also detail output
        mdb = DataFrame(CSV.File(detail_path))
        failed = antijoin(ldb, mdb, on = [:guide, :distance, :chromosome, :start, :strand])
        @test nrow(failed) == 0
    end
end