push!(LOAD_PATH, "../src/")
using Documenter, CHOPOFF
DocMeta.setdocmeta!(CHOPOFF, :DocTestSetup, :(using CHOPOFF, BioSequences); recursive=true)

makedocs(
    clean = true,
    doctest = true,
    sitename = "CHOPOFF.jl",
    authors = "Kornel Labun",
    format = Documenter.HTML(
        sidebar_sitename = false,
        footer = "Made with ♥ by Kornel Labun.",
        assets = ["assets/theme.css"],
        disable_git = true
    ),
    # warnonly = Documenter.except(:linkcheck, :footnote), # may allow to build on git
    modules  = [CHOPOFF],
    pages = [
        "General" => "index.md",
        "API" => Any[
            "Abstract gRNA" => "abstract_gRNA.md",
            "Find potential off-targets" => "find_potential_ot.md",
            "Align gRNA and off-target" => "align_gRNA.md",
            "Alignment-free filters for gRNAs" => "alignment_free.md",
            "Find all off-targets" => "find_ot.md",
            "Utils" => "utils.md"],
        ])

# uncomment when repo becomes public
#deploydocs(
#    repo = "github.com/JokingHero/CHOPOFF.jl.git",
#    target = "build",
#    branch = "gh-pages",
#    versions = nothing, # currently make things simple
#    push_preview = true,
#)
