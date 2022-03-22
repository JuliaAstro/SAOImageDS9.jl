# SAOImageDS9.jl

This [Julia](http://julialang.org/) package provides an interface to the image
viewer [SAOImage/DS9](http://ds9.si.edu/site/Home.html) via
[XPA.jl](https://github.com/JuliaAstro/XPA.jl), a Julia interface to the [XPA
Messaging System](https://github.com/ericmandel/xpa).


| **Documentation**               | **License**                     | **Build Status**              |
|:-------------------------------:|:-------------------------------:|:-----------------------------:|
| [![][doc-dev-img]][doc-dev-url] | [![][license-img]][license-url] | [![][gha-img]][gha-url] |


## Installation

You can install this package from the general registry

```julia
julia> ] add SAOImageDS9
```

## Usage

First, load the package 

```julia
julia> using SAOImageDS9
```

the alias `DS9` is exported for convenience. First you'll need to connect to an existing DS9 instance

```julia
julia> DS9.connect()
```

Once your connection is estabblished, you can use `DS9.set` to issue commands or `DS9.draw` to plot data. For more information, usage, and API reference, see the [online documentation][doc-stable-url].


[doc-stable-img]: https://img.shields.io/badge/docs-stable-blue.svg
[doc-stable-url]: https://JuliaAstro.github.io/SAOImageDS9.jl/stable

[doc-dev-img]: https://img.shields.io/badge/docs-dev-blue.svg
[doc-dev-url]: https://JuliaAstro.github.io/SAOImageDS9.jl/dev

[license-url]: LICENSE
[license-img]: https://img.shields.io/github/license/JuliaAstro/SAOImageDS9.jl?color=yellow

[gha-img]: https://github.com/juliaastro/SAOImageDS9.jl/workflows/CI/badge.svg?branch=master
[gha-url]: https://github.com/juliaastro/SAOImageDS9.jl/actions

[codecov-img]: https://codecov.io/gh/juliaastro/SAOImageDS9.jl/branch/master/graph/badge.svg?branch=master
[codecov-url]: https://codecov.io/gh/juliaastro/SAOImageDS9.jl

[julia-url]: https://julialang.org/
[julia-pkgs-url]: https://pkg.julialang.org/
