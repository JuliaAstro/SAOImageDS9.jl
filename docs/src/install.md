# Installation

To use this package, the SAOImage/DS9 program and the
[XPA](https://github.com/ericmandel/xpa) dynamic library and headers must be
installed on your computer.  If this is not the case, they are available for
different operating systems.  For example, on Debian or Ubuntu-like Linux
system, you can call `apt-get` from the command line:

```sh
sudo apt-get install saods9 libxpa-dev
```

DS9.jl can be can be installed by Julia's package manager:

```
... pkg> add https://github.com/JuliaAstro/DS9.jl
```

Another possibility from Julia's REPL or in a Julia script:

```julia
using Pkg
Pkg.add(PackageSpec(url="https://github.com/JuliaAstro/DS9.jl", rev="master"))
```

See [XPA.jl site](https://github.com/JuliaAstro/XPA.jl) for instructions about
how to install this package if the installation of DS9.jl fails to properly
install this required package.

To upgrade the DS9.jl package:

```julia
using Pkg
Pkg.update("DS9")
```

There is nothing to build.
