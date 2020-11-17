# Changes in SAOImageDS9.jl package

## Version 0.2.0

- Name changed to `SAOImageDS9`.

- Use the per-thread persistent client connection now provided by `XPA.jl`.
  As a result, `SAOImageDS9.connection()` is just `XPA.connection()`.

- Try to automatically connect to a running SAOImage/DS9 application if an
  access point has not yet been specified.

- New method `SAOImageDS9.draw` to draw or display various things (image,
  points, rectangles, ...) in SAOImage/DS9.
