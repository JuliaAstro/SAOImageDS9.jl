DEPLOYDOCS = (get(ENV, "CI", nothing) == "true")
push!(LOAD_PATH, "../src/")
using SAOImageDS9
using Documenter
using Documenter.Remotes: GitHub

include("pages.jl")

makedocs(;
    modules = [SAOImageDS9],
    sitename = "SAOImageDS9.jl",
    repo = GitHub("JuliaAstro/SAOImageDS9.jl"),
    format = Documenter.HTML(
        canonical = "https://juliaastro.org/SAOImageDS9/stable/",
        prettyurls = DEPLOYDOCS,
    ),
    authors = "Éric Thiébaut and contributors",
    pages = pages,
    doctest = true,
    checkdocs = :export,
)

if DEPLOYDOCS
    deploydocs(
        repo = "github.com/JuliaAstro/SAOImageDS9.jl.git",
        push_preview = true,
        versions = ["stable" => "v^", "v#.#"], # Restrict to minor releases
    )
end
