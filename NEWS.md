# Changes in SAOImageDS9.jl package

## Unreleased

### Breaking changes

Public methods are now exported with the prefix `ds9`, it is no longer necessary to use
the `SAOImageDS9.` prefix.

- `ds9accesspoint` replaces `SAOImageDS9.accesspoint` to get the access-point of the
  default SAOImage/DS9 application.
- `ds9connect` replaces `SAOImageDS9.connect` to connect to the default SAOImage/DS9 application.
- `ds9draw` replaces `SAOImageDS9.draw` to draw something in SAOImage/DS9.
- `ds9get` replaces `SAOImageDS9.get` to send an XPA *get* request to SAOImage/DS9.
- `ds9set` replaces `SAOImageDS9.set` to send an XPA *set* request to SAOImage/DS9.

As was the case for `SAOImageDS9.get`, method `ds9get` may convert the binary data
associated with the answer to a variety of result types but no longer *scan* or *parse*
the answer interpreted as an ASCII string. This is the job of the new method `ds9scan`.
This is to favor type-stable results and to more clearly indicate how is interpreted the
answer of an XPA *get* request. For example, to retrieve a vector of bytes with the pixel
data (there are of course better ways to retrieve the pixels as an array):

```julia
SAOImageDS9.get(Vector{UInt8}, "array") # previously
ds9get(Vector{UInt8}, "array") # now
```

As another example, to deal with an answer that is an ASCII string:

```julia
# Retrieve the answer interpreted as an ASCII string:
SAOImageDS9.get(String, "fits size") # previously
ds9get(String, "fits size") # now
# Scan the answer interpreted as an ASCII string:
SAOImageDS9.get(Tuple{Vararg{Int}}, "fits size") # previously, not type stable
ds9scan(NTuple{2,Int}, "fits size") # now, type-stable but require to know N
ds9scan(Vector{Int}, "fits size") # now, type-stable
```

Note that `ds9get(Vector{Int}, "fits size")` would have returned the bytes of the answer
interpreted as a vector of `Int`s.

### Added or changed

Exported public methods:

- `ds9accesspoint` to get the access-point of the default SAOImage/DS9 application.
- `ds9connect` to connect to the default SAOImage/DS9 application.
- `ds9cursor` to interactively select a position in SAOImage/DS9.
- `ds9disconnect` to disconnect from the default SAOImage/DS9 application.
- `ds9draw` to draw something in SAOImage/DS9.
- `ds9get` to send an XPA *get* request to SAOImage/DS9.
- `ds9getregions` to get regions defined in SAOImage/DS9.
- `ds9launch` to launch the default SAOImage/DS9 application.
- `ds9message` to display a simple message dialog in SAOImage/DS9.
- `ds9quit` to make SAOImage/DS9 to quit.
- `ds9scan` to send an XPA *get* request to SAOImage/DS9 and scan the textual result.
- `ds9set` to send an XPA *set* request to SAOImage/DS9.
- `ds9wcs` to get the FITS cards defining the WCS transform in SAOImage/DS9.

Non-exported public methods:

- `SAOImageDS9.bitpix_of(x)` yields FITS bits-per-pixel (BITPIX) value for `x`
- `SAOImageDS9.bitpix_to_type(bpp)` yields Julia type correctly to FITS BITPIX (bits-per-pixel)
  `bpp`.

The management of the connection to the default SAOImage/DS9 server has been enriched.
Connection is automatically established if not yet done, user may interactively choose one
of the available servers if more than one are found, the server selection can be
customized via filter and selection functions, etc.

## Version 0.2.1 (2025-06-24)

- Fixes in a few `SAOImageDS9.set` commands.

## Version 0.2.0

- Name changed to `SAOImageDS9`.

- Use the per-thread persistent client connection now provided by `XPA.jl`.
  As a result, `SAOImageDS9.connection()` is just `XPA.connection()`.

- Try to automatically connect to a running SAOImage/DS9 application if an
  access point has not yet been specified.

- New method `SAOImageDS9.draw` to draw or display various things (image,
  points, rectangles, ...) in SAOImage/DS9.
