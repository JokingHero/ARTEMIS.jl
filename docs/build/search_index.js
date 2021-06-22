var documenterSearchIndex = {"docs":
[{"location":"#CRISPRofftargetHunter","page":"Home","title":"CRISPRofftargetHunter","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Software designed for efficient, precise and fast identification of all off-targets for given CRISPR guideRNA's. It leverages couple of alghoritms designed specifically for this purpose.","category":"page"},{"location":"","page":"Home","title":"Home","text":"CRISPRofftargetHunter is extensively tested:","category":"page"},{"location":"","page":"Home","title":"Home","text":"unit tests for each function\nfriction tests where three different implementations of the same functionality must report the same results\nend-to-end tests where we run whole pipeline on specially designed sample genome and compare results with CRISPRitz software","category":"page"},{"location":"","page":"Home","title":"Home","text":"CRISPRofftargetHunter is designed specifically for CRISPR alignments of guideRNA's, allowing for deletions, insretions and mismatches. Implemented alghoritms allow you to find off-targets within distance as large as you want!","category":"page"},{"location":"","page":"Home","title":"Home","text":"CRISPRofftargetHunter has an alghoritm (see: build_sketchDB and search_sketchDB) designed for super fast estimation of number of off-targets in the genome. These estimations can never report counts less than reality, but can only over-estimate! This can be used to quickly design libraries of guideRNA's for the entire genomes, as promising guides can be quickly sorted using CRISPRofftargetHunter.","category":"page"},{"location":"","page":"Home","title":"Home","text":"CRISPRofftargetHunter has support for multiple-cores, we use standard julia configuration for that.","category":"page"},{"location":"#Citation","page":"Home","title":"Citation","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"TODO","category":"page"},{"location":"#LICENSE","page":"Home","title":"LICENSE","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Copyright (C) 2021  Kornel Labun","category":"page"},{"location":"","page":"Home","title":"Home","text":"This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.","category":"page"},{"location":"","page":"Home","title":"Home","text":"This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public License for more details.","category":"page"},{"location":"","page":"Home","title":"Home","text":"You should have received a copy of the GNU Affero General Public License along with this program.  If not, see https://www.gnu.org/licenses/.","category":"page"},{"location":"#Self-contained-build","page":"Home","title":"Self-contained build","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"It is possible to build CRISPRofftargetHunter into standalone application. This can be achieved by running ./build_standalone.sh script from the main directory. Script will produce binary in a new folder outside the main directory. Then you can run from inside that folder ./bin/CRISPRofftargetHunter --help or ./bin/CRISPRofftargetHunter build --help.","category":"page"},{"location":"#Main-API","page":"Home","title":"Main API","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Run CRISPRofftargetHunter as an application. From the directory of the package run:","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia --threads 4 --project=\".\" CRISPRofftargetHunter.jl --help","category":"page"},{"location":"#Example","page":"Home","title":"Example","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"TODO","category":"page"},{"location":"#Public-Interface","page":"Home","title":"Public Interface","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"You can also use CRISPRofftargetHunter as a normal julia package with the exported functions.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Motif\nbuild_linearDB\nsearch_linearDB\nbuild_sketchDB\nsearch_sketchDB\nbuild_treeDB\nsearch_treeDB\ninspect_treeDB","category":"page"},{"location":"#CRISPRofftargetHunter.Motif","page":"Home","title":"CRISPRofftargetHunter.Motif","text":"Motif(     alias::String,     fwdmotif::String,      fwdpam::String,      forward_strand::Bool = true,      reverse_strand::Bool = true,      distance::Int = 4,      extends5::Bool = true)\n\nMotif(alias::String)\n\nMotif defines what we search on the genome, what can be identified as an off-target.\n\nArguments\n\nalias - alias of the motif for easier identification e.g. Cas9\n\nfwdmotif - Motif that indicates where is PAM inside fwdpam.     For example for Cas9 it is 20*N + XXX: NNNNNNNNNNNNNNNNNNNNXXX\n\nfwdpam   - Motif in 5'-3' that will be matched on the reference (without the X).              For example for Cas9 it is 20*X + NGG:              XXXXXXXXXXXXXXXXXXXXNGG\n\nforward  - If false will not match to the forward reference strand.\n\nreverse  - If false will not match to the reverse reference strand.\n\ndistance - How many extra nucleotides are needed for a search? This              will indicate within what distance we can search for off-targets.              When we don't have those bases we use DNA_Gap.\n\nextend5  - Defines how off-targets will be aligned to the guides and where              extra nucleotides will be added for alignment within distance. Whether              to extend in the 5' and 3' direction. Cas9 is extend5 = true.\n\nExample for Cas9 where we want to search for off-targets within distance of 4:\n  alias:    Cas9\n  fwdmotif: NNNNNNNNNNNNNNNNXXX\n  fwdpam:   XXXXXXXXXXXXXXXXNGG\n  forward:  true\n  reverse:  true\n  distance: 4\n  extend5:  true\n\nAlignments will be performed from opposite to the extension direction (which is deifned by extend5).\n\nExamples\n\nMotif('Cas9')\nMotif('Cas9', 'NNNNNNNNNNNNNNNNXXX', 'XXXXXXXXXXXXXXXXNGG'. true, true, 3, true)\n\n\n\n\n\n","category":"type"},{"location":"#CRISPRofftargetHunter.build_linearDB","page":"Home","title":"CRISPRofftargetHunter.build_linearDB","text":"build_linearDB(     name::String,     genomepath::String,     motif::Motif,     storagedir::String,     prefix_len::Int = 7)\n\nBuild a DB of offtargets for the given motif, DB groups off-targets by their prefixes.\n\nWill return a path to the database location, same as storagedir. When this database is used for the guide off-target scan it is similar  to linear in performance, hence the name.\n\nThere is an optimization that if the alignment becomes imposible against the prefix we don't search the off-targets grouped inside the prefix. Therefore it is advantageous to select larger prefix than maximum  search distance, however in that case number of files also grows.\n\n\n\n\n\n","category":"function"},{"location":"#CRISPRofftargetHunter.search_linearDB","page":"Home","title":"CRISPRofftargetHunter.search_linearDB","text":"search_linearDB(storagedir::String, guides::Vector{LongDNASeq}, dist::Int = 4; detail::String = \"\")\n\nWill search the previously build database for the off-targets of the guides.  Assumes your guides do not contain PAM, and are all in the same direction as  you would order from the lab e.g.:\n\n` 5' - ...ACGTCATCG NGG - 3'  -> will be input: ...ACGTCATCG      guide        PAM\n\n3' - CCN GGGCATGCT... - 5'  -> will be input: ...AGCATGCCC      PAM guide `\n\nArguments\n\ndist - defines maximum levenshtein distance (insertions, deletions, mismatches) for which off-targets are considered.   detail - path and name for the output file. This search will create intermediate  files which will have same name as detail, but with a sequence prefix. Final file will contain all those intermediate files. Leave detail empty if you are only  interested in off-target counts returned by the linearDB.  \n\n\n\n\n\n","category":"function"},{"location":"#CRISPRofftargetHunter.build_sketchDB","page":"Home","title":"CRISPRofftargetHunter.build_sketchDB","text":"build_sketchDB(     name::String,      genomepath::String,      motif::Motif,     storagedir::String,     probability_of_error::Float64 = 0.001;      max_count::Int = 255)\n\nBuild Count-Min-Sketch database that can never under-estimate the counts of off-targets.\n\nArguments\n\nname - Your name for this database.   genomepath - Path to the genome in either .2bit or .fa format. motif- See Motif type.   storagedir- Where should be the output folder.   probability_of_error- This is error level for each individual off-target search.      This error will be propagated when doing searches for larger distances and therefore      will not be perfectly reflected in the results.  \n\nmax_count - What is the maximum count for each specific off-target in the genome. We     normally care only for guides that have low off-target count, therefore we can keep this     value also low, this saves space and memory usage.\n\n\n\n\n\n","category":"function"},{"location":"#CRISPRofftargetHunter.search_sketchDB","page":"Home","title":"CRISPRofftargetHunter.search_sketchDB","text":"search_sketchDB(     storagedir::String,     guides::Vector{LongDNASeq},     dist::Int = 2)\n\nFor each of the input guides will check in the sketchDB  what value Count-Min Sketch has for it in the first, and  in the second column will output kmer sum. Results  are estimations of offtarget counts in the genome.\n\nIf CMS column is 0, it is guaranteed this guide has  no 0-distance off-targets in the genome!\n\nAlso, maximum count for each off-target in the database is capped, to max_count specified during building of sketchDB. This means  that counts larger than max_count (default 255) are no longer estimating correclty, but we know at least 255 off-targets exist in  the genome. Its likely you would not care for those guides anyhow.\n\n\n\n\n\n","category":"function"},{"location":"#CRISPRofftargetHunter.build_treeDB","page":"Home","title":"CRISPRofftargetHunter.build_treeDB","text":"build_treeDB(     name::String,     genomepath::String,     motif::Motif,     storagedir::String,     prefix_len::Int = 7)  \n\nBuild a Vantage Point tree DB of offtargets for the given motif, DB groups off-targets by their prefixes, each prefix has its own Vantage Point tree.\n\nWill return a path to the database location, same as storagedir.\n\nThere is an optimization that if the alignment becomes imposible against the prefix we don't search the off-targets grouped inside the prefix. Therefore it is advantageous to select larger prefix than maximum  search distance, however in that case number of files also grows.\n\n\n\n\n\n","category":"function"},{"location":"#CRISPRofftargetHunter.search_treeDB","page":"Home","title":"CRISPRofftargetHunter.search_treeDB","text":"search_treeDB(storagedir::String, guides::Vector{LongDNASeq}, dist::Int = 4; detail::String = \"\")\n\nWill search the previously build database for the off-targets of the guides.  Assumes your guides do not contain PAM, and are all in the same direction as  you would order from the lab e.g.:\n\n5' - ...ACGTCATCG NGG - 3'  -> will be input: ...ACGTCATCG\n     guide        PAM\n\n3' - CCN GGGCATGCT... - 5'  -> will be input: ...AGCATGCCC\n     PAM guide\n\nArguments\n\ndist - defines maximum levenshtein distance (insertions, deletions, mismatches)  for which off-targets are considered.\n\ndetail - path and name for the output file. This search will create intermediate  files which will have same name as detail, but with a sequence prefix. Final file  will contain all those intermediate files. Leave detail empty if you are only  interested in off-target counts returned by the searchDB.\n\n\n\n\n\n","category":"function"},{"location":"#CRISPRofftargetHunter.inspect_treeDB","page":"Home","title":"CRISPRofftargetHunter.inspect_treeDB","text":"inspect_treeDB(storagedir::String; levels::Int = 5, inspect_prefix::String = \"\")\n\nSee small part of the full vantage point tree of the treeDB.\n\n\n\n\n\n","category":"function"}]
}
