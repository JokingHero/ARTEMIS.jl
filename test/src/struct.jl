using Test

using CRISPRofftargetHunter: DBInfo, Loc, decode, 
    Motif, length_noPAM, removepam, combinestrings, notX,
    AmbigIdx, findbits
using BioSequences

@testset "structures" begin

    cas9 = Motif(
        "Cas9",
        "NNNNNNNNNNNNNNNNNNNNXXX",
        "XXXXXXXXXXXXXXXXXXXXNGG", true, true, 4, true, 0)
    cpf1 = Motif("Cpf1")
    @testset "Motif" begin
        @test length_noPAM(cas9) == 24
        @test length_noPAM(cpf1) == 24
        @test removepam(dna"ACTNN", 1:3) == dna"NN"
        @test combinestrings("XXXACT", "ACTXXX") == "ACTACT"
    end


    @testset "DBInfo & Loc" begin
        dbi = DBInfo("./sample_data/genome/semirandom.fa", "test", cas9)
        @test dbi.is_fa == true
        @test length(dbi.chrom) == 8
        loc = Loc{dbi.chrom_type, dbi.pos_type}(1, 10, true)
        @test "semirandom1,10,+" == decode(loc, dbi)
    end


    @testset "AmbigIdx" begin
        guides = [dna"ACTG", dna"NNAC", dna"GGAA", dna"GGAA"]
        annot = [
            Vector{String}(["rs131", "rs1"]), Vector{String}(), 
            Vector{String}(), Vector{String}()]
        idx = AmbigIdx(guides, annot)
        @test sum(findbits(dna"AAAC", idx)) == 1
        @test sum(findbits(dna"GGAA", idx)) == 2
        @test sum(findbits(dna"GCAA", idx)) == 0
        @test sum(findbits(dna"GGA", idx)) == 3
        @test idx.annot[findbits(dna"ACTG", idx)][1] == Vector{String}(["rs131", "rs1"])
    end
end