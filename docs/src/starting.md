# Starting

In your Julia code/session, it is sufficient to do:

```julia
import DS9
DS9.connect()
```
or:

```julia
using DS9
DS9.connect()
```

which are equivalent as `DS9.jl` does not export any symbols.  Thus all
commands are prefixed by `DS9.`, if you prefer a different prefix, you can do
something like:

```julia
const ds9 = DS9
```

The `DS9.connect` call is needed to establish a connection to SAOImage/DS9
(which must be running).  With no arguments, `DS9.connect` chooses the first
available server matching `"DS9:*"`.  It is possible to specify an argument to
`DS9.connect` to choose a given server.

If you only want to connect to SAOImage/DS9 if no connections have already been
established:

```julia
if DS9.accesspoint() == ""
    DS9.connect()
end
```

To check the connection to SAOImage/DS9, you can type:

```julia
DS9.get(VersionNumber)
```

which should gives you the version of the SAOImage/DS9 to which you are
connected.
