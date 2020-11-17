# Installation

To use this package, the SAOImage/DS9 program and the
[XPA](https://github.com/ericmandel/xpa) dynamic library and headers must be
installed on your computer.  If this is not the case, they are available for
different operating systems.  For example, on Debian or Ubuntu-like Linux
system, you can call `apt-get` from the command line:

```sh
sudo apt-get install saods9 libxpa-dev
```

`SAOImageDS9` can be can be installed by Julia's package manager:

```
... pkg> add https://github.com/JuliaAstro/SAOImageDS9.jl
```

Another possibility from Julia's REPL or in a Julia script:

```julia
using Pkg
Pkg.add(PackageSpec(url="https://github.com/JuliaAstro/SAOImageDS9.jl", rev="master"))
```

See [XPA.jl site](https://github.com/JuliaAstro/XPA.jl) for instructions about
how to install this package if the installation of `SAOImageDS9` fails to
properly install this required package.

To upgrade the `SAOImageDS9` package:

```julia
using Pkg
Pkg.update("SAOImageDS9")
```

There is nothing to build.
