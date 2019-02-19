# Installation

To use this package, the SAOImage/DS9 program and the
[XPA](https://github.com/ericmandel/xpa) dynamic library and headers must be
installed on your computer.  If this is not the case, they are available for
different operating systems.  For example, on Debian or Ubuntu-like Linux
system, you can call `apt-get` from the command line:

```sh
sudo apt-get install saods9 xpa-tools
```

To install the DS9.jl package, start Julia in interactive mode and do:

```julia
using Pkg
Pkg.clone("https://github.com/emmt/DS9.jl")
```

Don't be feared with the warning message about using deprecated `Pkg.clone`
instead of `Pkg.add`, as of Julia 1.0,
`Pkg.add("https://github.com/emmt/DS9.jl")` does not work in spite of what said
the Julia documentation...

See [XPA.jl site](https://github.com/emmt/XPA.jl) for instructions about how to
install this package if the installation of DS9.jl fails to properly install
this required package.

To upgrade the DS9.jl package:

```julia
Pkg.update("DS9")
```

There is nothing to build.
