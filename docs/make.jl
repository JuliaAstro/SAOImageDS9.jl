using Documenter
using SAOImageDS9

include("pages.jl")

makedocs(
    modules = [SAOImageDS9],
    sitename = "SAOImageDS9.jl",
    format = Documenter.HTML(),
    authors = "Éric Thiébaut and contributors",
    pages = pages,
    doctest = true,
    checkdocs = :export,
)

deploydocs(
    repo = "github.com/JuliaAstro/SAOImageDS9.jl.git",
    push_preview = true,
)
