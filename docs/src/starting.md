# Starting



To use `SAOImageDS9` package, type:

```julia
using SAOImageDS9
```

will import the symbol `DS9` which can be used to prefix all methods
available in `SAOImageDS9` instead of the full package name which can be a bit
tedious in interactive sessions.  If you prefer another prefix, say `sao`,
you can do:

```julia
import SAOImageDS9
const sao = SAOImageDS9
```

or (provided your Julia version is at least 1.6):

```julia
import SAOImageDS9 as sao
```

You may also just `import SAOImageDS9` and keep the `SAOImageDS9` prefix.
Throughout all the remaining documentation, no shortcut is assumed.

You may call the [`SAOImageDS9.connect`](@ref) method to specify the access
point to a given running SAOImage/DS9 application.  If no given access point is
specified, `SAOImageDS9` will automatically attempts to connect to the first
access point matching `"DS9.*"` when a command is sent to SAOImage/DS9.  The
method [`SAOImageDS9.accesspoint()`](@ref) yields the name of the current
access point to SAOImage/DS9, or an empty string if none has been chosen.

To check the connection to SAOImage/DS9, you can type:

```julia
SAOImageDS9.get(VersionNumber)
```

which should yield the version of the SAOImage/DS9 to which you are connected.
