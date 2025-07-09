# Changes in SAOImageDS9.jl package


## Unreleased

### Added or Changed

- Many methods are now exported with the prefix `ds9`:

  - `ds9accesspoint` to get the XPA access-point of the default SAOImage/DS9 application.
  - `ds9connect` to connect to the default SAOImage/DS9 application.
  - `ds9cursor` to interactively select a position in SAOImage/DS9.
  - `ds9disconnect` to disconnect from the default SAOImage/DS9 application.
  - `ds9draw` replaces `SAOImageDS9.draw` to draw something in SAOImage/DS9.
  - `ds9get` replaces `SAOImageDS9.get` to send an XPA *get* request to SAOImage/DS9.
  - `ds9getregions` to get regions defined in SAOImage/DS9.
  - `ds9message` to display a simple message dialog in SAOImage/DS9.
  - `ds9launch` to launch the default SAOImage/DS9 application.
  - `ds9quit` to make SAOImage/DS9 to quit.
  - `ds9scan` to send an XPA *get* request to SAOImage/DS9 and scan the textual result.
  - `ds9set` replaces `SAOImageDS9.set` to send an XPA *set* request to SAOImage/DS9.
  - `ds9wcs` to get the FITS cards defining the WCS transform in SAOImage/DS9.


## Version 0.2.0

- Name changed to `SAOImageDS9`.

- Use the per-thread persistent client connection now provided by `XPA.jl`.
  As a result, `SAOImageDS9.connection()` is just `XPA.connection()`.

- Try to automatically connect to a running SAOImage/DS9 application if an
  access point has not yet been specified.

- New method `SAOImageDS9.draw` to draw or display various things (image,
  points, rectangles, ...) in SAOImage/DS9.
