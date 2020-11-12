# Changes in DS9.jl package

## Version 0.2.0

- Use the per-thread persistent client connection now provided by `XPA.jl`.
  As a result, `DS9.connection()` is just `XPA.connection()`.

- Try to automatically connect to a running SAOImage/DS9 application if an
  access point has not yet been specified.
