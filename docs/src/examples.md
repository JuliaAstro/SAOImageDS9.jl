# Examples


## Basic examples

```julia
using SAOImageDS9
using SAOImageDS9: TupleOf
DS9.connect()
```

For a 512×861 image `img` with `Float32` pixels, `DS9.set(img)` takes
8.502 ms (28 allocations: 1.30 KiB) while `DS9.get(Array)` takes
5.844 ms (50 allocations: 1.68 MiB).


Query parameters of the image displayed in the current DS9 frame:
```julia
DS9.get(Int, "fits width")         # get the width of the image
DS9.get(Int, "fits height")        # get the height of the image
DS9.get(Int, "fits depth")         # get the depth of the image
DS9.get(Int, "fits bitpix")        # get the bits per pixel of the image
DS9.get(TupleOf{Int}, "fits size") # get the dimensions of the image
```
The dimensions are ordered as `width`, `height` and `depth`.

To retrieve or set the dimensions of the display window:
```julia
DS9.get(Int, "width")    # get the width of the image display window
DS9.get(Int, "height")   # get the height of the image display window
DS9.set("width", n)      # set the width of the image display window
DS9.set("height", n)     # set the height of the image display window
```

Display an image and set the scale limits:
```julia
DS9.set(img)
DS9.set("scale limits", 0, maximum(img))
```

## Frame settings

### Set frame settings

```julia
DS9.set("frame center")       # center current frame
DS9.set("frame center",1)     # center 'Frame1'
DS9.set("frame center all")   # center all frames
DS9.set("frame clear")        # clear current frame
DS9.set("frame new")          # create new frame
DS9.set("frame new rgb")      # create new rgb frame
DS9.set("frame delete")       # delete current frame
DS9.set("frame reset")        # reset current frame
DS9.set("frame refresh")      # refresh current frame
DS9.set("frame hide")         # hide current frame
DS9.set("frame show",1)       # show frame 'Frame1'
DS9.set("frame move first")   # move frame to first in order
DS9.set("frame move back")    # move frame back in order
DS9.set("frame move forward") # move frame forward in order
DS9.set("frame move last")    # move frame to last in order
DS9.set("frame first")        # goto first frame
DS9.set("frame prev")         # goto prev frame
DS9.set("frame next")         # goto next frame
DS9.set("frame last")         # goto last frame
DS9.set("frame frameno 4")    # goto frame 'Frame4',create if needed
DS9.set("frame", 3)           # goto frame 'Frame3',create if needed
DS9.set("frame match wcs")
DS9.set("frame lock wcs")
```

### Get frame settings

```julia
DS9.get(Int, "frame")            # returns the id of the current frame
DS9.get(Int, "frame frameno")    # returns the id of the current frame
DS9.get(TupleOf{Int}, "frame all")    # returns the id of all frames
DS9.get(TupleOf{Int}, "frame active") # returns the id of all active frames
DS9.get(String, "frame lock")
DS9.get(Bool, "frame has amplifier")
DS9.get(Bool, "frame has datamin")
DS9.get(Bool, "frame has datasec")
DS9.get(Bool, "frame has detector")
DS9.get(Bool, "frame has grid")
DS9.get(Bool, "frame has iis")
DS9.get(Bool, "frame has irafmin")
DS9.get(Bool, "frame has physical")
DS9.get(Bool, "frame has smooth")
DS9.get(Bool, "frame has contour")
DS9.get(Bool, "frame has contour aux")
DS9.get(Bool, "frame has fits")
DS9.get(Bool, "frame has fits bin")
DS9.get(Bool, "frame has fits cube")
DS9.get(Bool, "frame has fits mosaic")
DS9.get(Bool, "frame has marker highlite")
DS9.get(Bool, "frame has marker paste")
DS9.get(Bool, "frame has marker select")
DS9.get(Bool, "frame has marker undo")
DS9.get(Bool, "frame has system physical")
DS9.get(Bool, "frame has wcs wcsa")
DS9.get(Bool, "frame has wcs equatorial wcsa")
DS9.get(Bool, "frame has wcs linear wcsa")
```


## Other examples

Get *about* string:

```julia
DS9.get(String, "about")
```

Get version number:

```julia
DS9.get(VersionNumber, "version")
```

Exit SAOImage/DS9:

```julia
DS9.set("exit")
```

Is SAOImage/DS9 iconified?

```julia
DS9.get(Bool, "iconify")
```

(De)iconify SAOImage/DS9:

```julia
DS9.set("iconify", bool)
```

```julia
DS9.set("lower")
DS9.set("raise") # can be used to de-iconify
```

Get/set zoom level:
```julia
DS9.get(Float64, "zoom")  # get current zoom level
DS9.set("zoom", value)
DS9.set("zoom to", value)
DS9.set("zoom to fit")
```

Rotation:
```julia
DS9.get(Float64, "rotate")
DS9.set("rotate", value)
DS9.set("rotate to", value)
DS9.set("rotate open")
DS9.set("rotate close")
```

```julia
DS9.get(String, "orient")
DS9.set("orient", value)
```

```julia
#iexam(;event::Union{AbstractString,Symbol}=:button) = get_words("iexam", event)

iexam(args...; event::Union{AbstractString,Symbol}=:button) =
    get_words("iexam", event, args...)

DS9.get(Int, :threads)  # get threads
DS9.set("threads", n)
```
