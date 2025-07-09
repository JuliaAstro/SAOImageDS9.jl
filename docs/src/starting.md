# Starting

To use `SAOImageDS9` package, type:

```julia
using SAOImageDS9
```

will import the public symbols of the package (all prefixed by `ds9`).

You may call the [`ds9connect`](@ref) method to specify the access point to a given
running SAOImage/DS9 application. If no given access point is specified,
[`ds9connect()`](@ref) will automatically attempt to connect to the first access point
matching `"DS9.*"` when a command is sent to SAOImage/DS9. The method
[`ds9accesspoint()`](@ref) yields the name of the current access point to SAOImage/DS9, or
an access-point with an empty address has been chosen or if [`ds9disconnect`](@ref) has
been called.

To check the connection to SAOImage/DS9, you can type:

```julia
ds9get(VersionNumber)
```

which should yield the version of the SAOImage/DS9 to which you are connected.
