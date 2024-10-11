using Documenter
using JMPReader

DocMeta.setdocmeta!(JMPReader, :DocTestSetup, :(using JMPReader); recursive = true)
const IS_CI = get(ENV, "CI", "false") == "true"

makedocs(
    modules = [JMPReader],
    authors = "Jaakko Ruohio",
    sitename = "JMPReader Documentation",
    format = Documenter.HTML(
		prettyurls = IS_CI,
        canonical = "https://jaakkor2.github.io/JMPReader.jl",
        ),
    warnonly = [:docs_block, :missing_docs, :cross_references],
#    remotes = nothing,
    pages = [
        "Usage" => "index.md",
        "Developer docs" => "dev.md",
        "Interoperability" => "interop.md",
        ],
    )

IS_CI && deploydocs(;
    repo = "github.com/jaakkor2/JMPReader.jl",
    push_preview = true,
    )

nothing
