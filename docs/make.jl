using Documenter
using JMPReader

DocMeta.setdocmeta!(JMPReader, :DocTestSetup, :(using JMPReader); recursive = true)

makedocs(
    modules = [JMPReader],
    authors = "Jaakko Ruohio",
    sitename = "JMPReader Documentation",
    format = Documenter.HTML(
		prettyurls = false,
        disable_git = false,
        canonical = "https://jaakkor2.github.io/JMPReader.jl",
        edit_link = "master",
        repolink = "https://github.com/jaakkor2/JMPReader.jl"
        ),
    warnonly = [:docs_block, :missing_docs, :cross_references],
#    remotes = nothing,
    pages = [
        "Usage" => "index.md",
        "Developer docs" => "dev.md",
        "Interoperability" => "interop.md",
        ],
    )

deploydocs(;
    repo = "github.com/jaakkor2/JMPReader.jl",
    devbranch = "master",
    )

nothing
