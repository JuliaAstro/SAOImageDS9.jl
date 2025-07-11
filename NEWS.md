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

Method `ds9get` is nearly equivalent to `SAOImageDS9.get`. `r = ds9get(T, cmd)` yields a
result `r` of type `T` from the *get* command `cmd`. If `T` is `eltype(XPA.Reply)`, `r` is
the bare un-processed answer and properties `r.data`, `r.message`, `r.has_message`,
`r.has_error` etc. may be used to deal with it. For all other types `T`, the answer is
interpreted as an ASCII string, the so-called *textual answer*. If `T` is `String`, `r` is
the textual answer unchanged. If `T` is a *tuple or vector type*, the textual answer is
split in words which are parsed according to the types of the entries of `T`. If `T` is a
*scalar type*, `r` is a value of type `T` parsed in the textual answer. Without `T`
specified, `ds9get(cmd)` is equivalent to `chomp(ds9get(String, cmd))`.

As a first example, to retrieve raw answer data or un-processed answer:

```julia
SAOImageDS9.get(Vector{UInt8}, "array") # previously, answer data as bytes
ds9get(eltype(XPA.Reply), "array") # now, fully un-processed answer
```

As another example, to deal with an answer that is an ASCII string:

```julia
# Retrieve the answer interpreted as an ASCII string:
SAOImageDS9.get(String, "fits size") # previously
ds9get(String, "fits size") # now
# Scan the answer interpreted as an ASCII string:
SAOImageDS9.get(Tuple{Vararg{Int}}, "fits size") # previously, not type stable
ds9get(NTuple{2,Int}, "fits size") # now, type-stable but require to know N
ds9get(Vector{Int}, "fits size") # now, type-stable
```

### Added or changed

Exported public methods:

- `ds9accesspoint` to get the access-point of the default SAOImage/DS9 application.
- `ds9connect` to connect to the default SAOImage/DS9 application.
- `ds9cursor` to interactively select a position in SAOImage/DS9.
- `ds9disconnect` to disconnect from the default SAOImage/DS9 application.
- `ds9draw` to draw something in SAOImage/DS9.
- `ds9get` to send an XPA *get* request to SAOImage/DS9.
- `ds9getregions` to get regions defined in SAOImage/DS9.
- `ds9iexam` like `ds9cursor` but, possibly, for other coordinate systems than `image`.
- `ds9launch` to launch the default SAOImage/DS9 application.
- `ds9message` to display a simple message dialog in SAOImage/DS9.
- `ds9quit` to make SAOImage/DS9 to quit.
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
