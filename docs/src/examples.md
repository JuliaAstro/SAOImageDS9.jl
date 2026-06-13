# Examples

This section provides examples of use of [`ds9get`](@ref) and [`ds9set`](@ref) to
communicate with SAOImage/DS9. You may refer to [this
page](https://ds9.si.edu/doc/ref/xpa.html) for a list of XPA commands implemented by
SAOImage/DS9. This documentation is also available via the menu *Help* > *Reference
Manual* > *XPA Access Points* of SAOImage/DS9.

## Basic examples

```julia
using SAOImageDS9
ds9connect()
```

For a 512×861 image `img` with `Float32` pixels, `ds9set(img)` takes 8.502 ms (28
allocations: 1.30 KiB) while `ds9get(Array)` takes 5.844 ms (50 allocations: 1.68 MiB).


Query parameters of the image displayed in the current SAOImage/DS9 frame:

```julia
ds9get(Int, "fits width")         # get the width of the image
ds9get(Int, "fits height")        # get the height of the image
ds9get(Int, "fits depth")         # get the depth of the image
ds9get(Int, "fits bitpix")        # get the bits per pixel of the image
ds9get(Vector{Int}, "fits size")  # get the dimensions of the image
```

Compared to a regular Julia's `Array`, SAOImage/DS9 dimensions are ordered as `width`,
`height`, and `depth`.

To retrieve or set the dimensions of SAOImage/DS9 window:

```julia
ds9get(Int, "width")    # get the width of SAOImage/DS9 window
ds9get(Int, "height")   # get the height of SAOImage/DS9 window
ds9set("width", npix)   # set the width of SAOImage/DS9 window
ds9set("height", npix)  # set the height of SAOImage/DS9 window
```

Display an image and set the scale limits:

```julia
ds9set(img)
ds9set("scale limits", 0, maximum(img))
```

## Frame settings

### Set frame settings

```julia
ds9set("frame center")       # center current frame
ds9set("frame center", 1)    # center frame 1
ds9set("frame center all")   # center all frames
ds9set("frame clear")        # clear current frame
ds9set("frame new")          # create new frame
ds9set("frame new rgb")      # create new rgb frame
ds9set("frame delete")       # delete current frame
ds9set("frame reset")        # reset current frame
ds9set("frame refresh")      # refresh current frame
ds9set("frame hide")         # hide current frame
ds9set("frame show", 7)      # show frame 7 if it exists
ds9set("frame move first")   # move frame to first in order
ds9set("frame move back")    # move frame back in order
ds9set("frame move forward") # move frame forward in order
ds9set("frame move last")    # move frame to last in order
ds9set("frame first")        # goto first frame
ds9set("frame prev")         # goto prev frame
ds9set("frame next")         # goto next frame
ds9set("frame last")         # goto last frame
ds9set("frame frameno 4")    # goto frame 4, create if needed
ds9set("frame", 3)           # goto frame 3, create if needed
ds9set("frame match wcs")
ds9set("frame lock wcs")
```

### Get frame settings

```julia
ds9get(Int, "frame")                # returns the id of the current frame
ds9get(Int, "frame frameno")        # returns the id of the current frame
ds9get(Vector{Int}, "frame all")    # returns the id of all frames
ds9get(Vector{Int}, "frame active") # returns the id of all active frames
ds9get(String, "frame lock")
```

To check whether the current frame has a specific settings:

```julia
ds9get(Bool, "frame has amplifier")
ds9get(Bool, "frame has datamin")
ds9get(Bool, "frame has datasec")
ds9get(Bool, "frame has detector")
ds9get(Bool, "frame has grid")
ds9get(Bool, "frame has iis")
ds9get(Bool, "frame has irafmin")
ds9get(Bool, "frame has physical")  # physical coordinates
ds9get(Bool, "frame has smooth")
ds9get(Bool, "frame has contour")
ds9get(Bool, "frame has contour aux")
ds9get(Bool, "frame has fits")
ds9get(Bool, "frame has fits bin")
ds9get(Bool, "frame has fits cube")
ds9get(Bool, "frame has fits mosaic")
ds9get(Bool, "frame has marker highlite")
ds9get(Bool, "frame has marker paste")
ds9get(Bool, "frame has marker select")
ds9get(Bool, "frame has marker undo")
ds9get(Bool, "frame has system physical")
ds9get(Bool, "frame has wcs wcsa")
ds9get(Bool, "frame has wcs equatorial wcsa")
ds9get(Bool, "frame has wcs linear wcsa")
```


## Other examples

Get *about* string as an array of strings (one for each line):

```julia-repl
julia> split(ds9get("about"),'\n')
12-element Vector{SubString{String}}:
 "SAOImageDS9"
 "Version 8.7b1"
 ""
 "Authors"
 "William Joye (Smithsonian Astrophysical Observatory)"
 "Eric Mandel (Smithsonian Astrophysical Observatory)"
 "Steve Murray (Smithsonian Astrophysical Observatory)"
 ""
 "Development funding"
 "NASA's Applied Information Systems Research Program (NASA/ETSO)"
 "Chandra X-ray Science Center (CXC)"
 "High Energy Astrophysics Science Archive Center (NASA/HEASARC)"
```

Get SAOImage/DS9 name and version number:

```julia-repl
julia> ds9get(Tuple{String, VersionNumber}, "version")
("ds9-8.7b1", v"8.7.0-b1")
```

Get version number, one of:

```julia
ds9get(Tuple{String, VersionNumber}, "version")[2]
ds9get(VersionNumber)
```

Exit SAOImage/DS9, one of:

```julia
ds9set("exit")
ds9set("quit")
ds9quit()
```

However, only the last one closes the connection.

Is SAOImage/DS9 iconified?

```julia
ds9get(Bool, "iconify")
```

(De)iconify SAOImage/DS9:

```julia
ds9set("iconify", bool)
```

```julia
ds9set("lower")
ds9set("raise") # can be used to de-iconify
```

Get/set zoom level:

```julia
ds9get(Float64, "zoom")  # get current zoom level
ds9set("zoom", value)
ds9set("zoom to", value)
ds9set("zoom to fit")
```

Rotation:

```julia
ds9get(Float64, "rotate")
ds9set("rotate", value)
ds9set("rotate to", value)
ds9set("rotate open")  # open Pan/Zoom/Rotate dialog
ds9set("rotate close") # close Pan/Zoom/Rotate dialog
```

Orientation (`none`, `x` to invert horizontal axis, `y` to invert vertical axis, `xy` to
invert both axes):

```julia
ds9get("orient") # yields one of "none", "x", "y", or "xy"
ds9set("orient", "y")
```

Get `(x,y,value)` in image where user clicked:
```julia
parse.(Float64, split(ds9get(String, "iexam {\$x \$y \$value}")))
```

## Get mouse cursor

To get key, position, and pixel value in image where user pressed a key:

```julia
(key,x,y,value) = ds9get(Tuple{String,Float64,Float64,Float64}, "iexam key {\$x \$y \$value}")
```

Idem but expecting user to click mouse button:

```julia
(x,y,val) = ds9get(NTuple{3,Float64}, "iexam button {\$x \$y \$value}")
```

Idem but expecting user to press a key or to click mouse button:

```julia
(key, x, y, val) = ds9get(Tuple{String,Float64,Float64,Float64}, "iexam any {\$x \$y \$value}")
```

[`ds9cursor`](@ref) implements an improved version of all these but with more options and
dealing with user selecting a position outside image area.

To get the coordinates in another coordinate system than the image one, use
[`ds9iexam`](@ref).


## Miscellaneous

Get and set the number of threads:

```julia
ds9get(Int, :threads)
ds9set("threads", n)
```
