using Documenter
using SAOImageDS9

include("pages.jl")

makedocs(
    sitename = "Connecting to SAOImage/DS9",
    format = Documenter.HTML(),
    authors = "Éric Thiébaut and contributors",
    pages = pages,
)

deploydocs(
    repo = "github.com/JuliaAstro/SAOImageDS9.jl.git",
)
