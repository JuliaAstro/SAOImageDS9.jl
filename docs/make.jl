using Documenter
using SAOImageDS9

DEPLOYDOCS = (get(ENV, "CI", nothing) == "true")

include("pages.jl")

makedocs(
    sitename = "Connecting to SAOImage/DS9",
    format = Documenter.HTML(
        prettyurls = DEPLOYDOCS,
    ),
    authors = "Éric Thiébaut and contributors",
    pages = pages,
)

if DEPLOYDOCS
    deploydocs(
        repo = "github.com/JuliaAstro/SAOImageDS9.jl.git",
    )
end
