# CHANGELOG

## DS9ui integration

I tried to comply to the [Julia Style
Guide](https://docs.julialang.org/en/v1/manual/style-guide) and to the [Blue
Style](https://github.com/JuliaDiff/BlueStyle)

### Added

- New `ds9select` method to allow the user to interact with a specific DS9
  window (based on the title)

- New `ds9` method to open a new DS9 window. Relies on the possibility to call
  DS9 from the shell with `ds9`. One could image more complex scenarios, but
  this is probably enough in most cases

- Now `get` without any type specification automatically converts the output
  to a suitable format

### Modified

- `accesspoint` now is not a `Ref` anymore: it is a typed global (so there is
  no type instability); it saves the full XPA.AccessPoint or `nothing` if no
  connection has been established. It is necessary to have `accesspoint` a
  more specific type rather than a string so that all the methods (such as
  `set`, `get`...) can accept the access point as an optional first argument.
  This is similar to other I/O methods.

- `get` now accepts an optional first argument, the access point. Also, all
  keywords are directly passed to `XPA.get`

- Fixed bug with `get(VersionNumber)` when the title of a DS9 window is not
  "ds9"

- `select` returns now _either_ the coordinates _or_ the data value: this is
  necessary to return coordinates in different coordinate systems

### Deleted

- Removed `_warn` definition: using `@warn` instead to keep using "standard"
  library routines

