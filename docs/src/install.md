# Installation

`SAOImageDS9` can be can be installed by Julia's package manager. In the Julia REPL, press
`]` to drop into package mode, then run:

```julia-repl
pkg> add SAOImageDS9
```

Another possibility from Julia's REPL or in a Julia script:

```julia
using Pkg
Pkg.add("SAOImageDS9")
# or
Pkg.add(PackageSpec(name="SAOImageDS9", rev="master"))
```

To upgrade the `SAOImageDS9` package:

```julia
using Pkg
Pkg.update("SAOImageDS9")
```

There is nothing to build.
