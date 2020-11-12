using Documenter

push!(LOAD_PATH,"../src/")
using DS9, XPA

DEPLOYDOCS = (get(ENV, "CI", nothing) == "true")

makedocs(
    sitename = "Connecting to SAOImage/DS9",
    format = Documenter.HTML(
        prettyurls = DEPLOYDOCS,
    ),
    authors = "Éric Thiébaut and contributors",
    pages = ["index.md", "install.md", "starting.md", "requests.md",
             "connect.md", "drawing.md", "library.md"]
)

if DEPLOYDOCS
    deploydocs(
        repo = "github.com/JuliaAstro/DS9.jl.git",
    )
end
