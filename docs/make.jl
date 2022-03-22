using Documenter
using SAOImageDS9

setup = quote
    using SAOImageDS9
end

DocMeta.setdocmeta!(SAOImageDS9, :DocTestSetup, setup; recursive = true)

makedocs(;
    modules=[SAOImageDS9],
    authors = "Éric Thiébaut and contributors",
    repo="https://github.com/JuliaAstro/SAOImageDS9.jl/blob/{commit}{path}#L{line}",
    sitename="SAOImageDS9.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://juliaastro.github.io/SAOImageDS9.jl",
        assets=String[],
    ),
    pages=[
        "index.md",
        "install.md",
        "starting.md",
        "requests.md",
        "connect.md",
        "drawing.md",
        "examples.md",
        "library.md"
    ],
)

deploydocs(;
    repo="github.com/JuliaAstro/SAOImageDS9.jl",
    devbranch="master"
)
