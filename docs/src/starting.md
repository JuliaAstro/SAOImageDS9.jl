# Starting

In your Julia code/session, it is sufficient to do:

```julia
import DS9
```
or:

```julia
using DS9
```

which are equivalent as `DS9.jl` does not export any symbols.  Thus all
commands are prefixed by `DS9.`, if you prefer a different prefix, you can do
something like:

```julia
const ds9 = DS9
```

You may call the [`DS9.connect`](@ref) method to specify the access point to a
given running SAOImage/DS9 application.  If no given access point is specified,
`DS9.jl` will automatically attempts to connect to the first access point
matching `"DS9.*"` when a command is sent to SAOImage/DS9.  The method
[`DS9.accesspoint()`](@ref) yields the name of the current access point to
SAOImage/DS9, or an empty string if none has been chosen.

To check the connection to SAOImage/DS9, you can type:

```julia
DS9.get(VersionNumber)
```

which should yield the version of the SAOImage/DS9 to which you are connected.
