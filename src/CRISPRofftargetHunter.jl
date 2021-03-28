__precompile__(true)

module CRISPRofftargetHunter

using CRC32c
using Dates
using Statistics
using Random
using Combinatorics
using BioSymbols
using BioSequences
using Serialization
using FASTX
using TwoBit
using Probably
using DataFrames
using StaticArrays
using ThreadsX

import Base.findall

include("utils.jl")
include("distance_metrics.jl")
include("motif.jl")
include("db_info.jl")
include("bitoperations.jl")

include("find_offtargets.jl")
include("find_offtargets_p.jl")

include("db_linear.jl")
include("db_sketch.jl")
include("db_tree.jl")

include("persistence.jl")

export getSeq, file_read, file_write, file_add, bucket_path, deleterange, getkmers, minkmersize, getkgrams # utils
export isinclusive, commonprefix, hamming, levenshtein, levenshtein2, Aln, PrefixAlignment, pa_sa
export levenshtein2_simple, levenshtein_bp, suffix_levenshtein, prefix_levenshtein # distance_metrics
export Motif # motif
export DBInfo, Loc, decode # genomeinfo
export SketchDB, save, load # persistence
export deletion_permutations # bitoperations
export gatherofftargets, gatherofftargets!, estimate, fillrate, iterate_over_offtargets # find_offtargets
export findofftargets_p_chrom, findofftargets_p_refg # find_offtargets_p
export buildlinearDB, LinearDB, searchlinearDB

end
