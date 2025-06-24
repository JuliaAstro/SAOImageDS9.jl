# Changes in SAOImageDS9.jl package

## Version 0.2.1 (2025-06-24)

- New `SAOImageDS9.select` method to interactively select a position in a
  running SAOImage/DS9 application.

- New `SAOImageDS9.message` method to display a simple message dialog in a
  running SAOImage/DS9 application.

- Fixes in a few `SAOImageDS9.set` commands.

## Version 0.2.0

- Name changed to `SAOImageDS9`.

- Use the per-thread persistent client connection now provided by `XPA.jl`.
  As a result, `SAOImageDS9.connection()` is just `XPA.connection()`.

- Try to automatically connect to a running SAOImage/DS9 application if an
  access point has not yet been specified.

- New method `SAOImageDS9.draw` to draw or display various things (image,
  points, rectangles, ...) in SAOImage/DS9.
