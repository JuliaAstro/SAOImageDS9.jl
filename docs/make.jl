using Documenter

push!(LOAD_PATH,"../src/")
using SAOImageDS9, XPA

DEPLOYDOCS = (get(ENV, "CI", nothing) == "true")

makedocs(
    sitename = "Connecting to SAOImage/DS9",
    format = Documenter.HTML(
        prettyurls = DEPLOYDOCS,
    ),
    authors = "Éric Thiébaut and contributors",
    pages = ["index.md", "install.md", "starting.md", "requests.md",
             "connect.md", "drawing.md", "examples.md", "library.md"]
)

if DEPLOYDOCS
    deploydocs(
        repo = "github.com/JuliaAstro/SAOImageDS9.jl.git",
    )
end
