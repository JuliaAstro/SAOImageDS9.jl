# Examples


## Basic examples

```julia
import SAOImageDS9
using SAOImageDS9: TupleOf
SAOImageDS9.connect()
```

For a 512×861 image `img` with `Float32` pixels, `SAOImageDS9.set(img)` takes
8.502 ms (28 allocations: 1.30 KiB) while `SAOImageDS9.get(Array)` takes 5.844
ms (50 allocations: 1.68 MiB).


Query parameters of the image displayed in the current DS9 frame:
```julia
SAOImageDS9.get(Int, "fits width")         # get the width of the image
SAOImageDS9.get(Int, "fits height")        # get the height of the image
SAOImageDS9.get(Int, "fits depth")         # get the depth of the image
SAOImageDS9.get(Int, "fits bitpix")        # get the bits per pixel of the image
SAOImageDS9.get(TupleOf{Int}, "fits size") # get the dimensions of the image
```
The dimensions are ordered as `width`, `height` and `depth`.

To retrieve or set the dimensions of the display window:
```julia
SAOImageDS9.get(Int, "width")    # get the width of the image display window
SAOImageDS9.get(Int, "height")   # get the height of the image display window
SAOImageDS9.set("width", n)      # set the width of the image display window
SAOImageDS9.set("height", n)     # set the height of the image display window
```

Display an image and set the scale limits:
```julia
SAOImageDS9.set(img)
SAOImageDS9.set("scale limits", 0, maximum(img))
```

## Frame settings

### Set frame settings

```julia
SAOImageDS9.set("frame center")       # center current frame
SAOImageDS9.set("frame center",1)     # center 'Frame1'
SAOImageDS9.set("frame center all")   # center all frames
SAOImageDS9.set("frame clear")        # clear current frame
SAOImageDS9.set("frame new")          # create new frame
SAOImageDS9.set("frame new rgb")      # create new rgb frame
SAOImageDS9.set("frame delete")       # delete current frame
SAOImageDS9.set("frame reset")        # reset current frame
SAOImageDS9.set("frame refresh")      # refresh current frame
SAOImageDS9.set("frame hide")         # hide current frame
SAOImageDS9.set("frame show",1)       # show frame 'Frame1'
SAOImageDS9.set("frame move first")   # move frame to first in order
SAOImageDS9.set("frame move back")    # move frame back in order
SAOImageDS9.set("frame move forward") # move frame forward in order
SAOImageDS9.set("frame move last")    # move frame to last in order
SAOImageDS9.set("frame first")        # goto first frame
SAOImageDS9.set("frame prev")         # goto prev frame
SAOImageDS9.set("frame next")         # goto next frame
SAOImageDS9.set("frame last")         # goto last frame
SAOImageDS9.set("frame frameno 4")    # goto frame 'Frame4',create if needed
SAOImageDS9.set("frame", 3)           # goto frame 'Frame3',create if needed
SAOImageDS9.set("frame match wcs")
SAOImageDS9.set("frame lock wcs")
```

### Get frame settings

```julia
SAOImageDS9.get(Int, "frame")            # returns the id of the current frame
SAOImageDS9.get(Int, "frame frameno")    # returns the id of the current frame
SAOImageDS9.get(TupleOf{Int}, "frame all")    # returns the id of all frames
SAOImageDS9.get(TupleOf{Int}, "frame active") # returns the id of all active frames
SAOImageDS9.get(String, "frame lock")
SAOImageDS9.get(Bool, "frame has amplifier")
SAOImageDS9.get(Bool, "frame has datamin")
SAOImageDS9.get(Bool, "frame has datasec")
SAOImageDS9.get(Bool, "frame has detector")
SAOImageDS9.get(Bool, "frame has grid")
SAOImageDS9.get(Bool, "frame has iis")
SAOImageDS9.get(Bool, "frame has irafmin")
SAOImageDS9.get(Bool, "frame has physical")
SAOImageDS9.get(Bool, "frame has smooth")
SAOImageDS9.get(Bool, "frame has contour")
SAOImageDS9.get(Bool, "frame has contour aux")
SAOImageDS9.get(Bool, "frame has fits")
SAOImageDS9.get(Bool, "frame has fits bin")
SAOImageDS9.get(Bool, "frame has fits cube")
SAOImageDS9.get(Bool, "frame has fits mosaic")
SAOImageDS9.get(Bool, "frame has marker highlite")
SAOImageDS9.get(Bool, "frame has marker paste")
SAOImageDS9.get(Bool, "frame has marker select")
SAOImageDS9.get(Bool, "frame has marker undo")
SAOImageDS9.get(Bool, "frame has system physical")
SAOImageDS9.get(Bool, "frame has wcs wcsa")
SAOImageDS9.get(Bool, "frame has wcs equatorial wcsa")
SAOImageDS9.get(Bool, "frame has wcs linear wcsa")
```


## Other examples

Get *about* string:

```julia
SAOImageDS9.get(String, "about")
```

Get version number:

```julia
SAOImageDS9.get(VersionNumber, "version")
```

Exit SAOImage/DS9:

```julia
SAOImageDS9.set("exit")
```

Is SAOImage/DS9 iconified?

```julia
SAOImageDS9.get(Bool, "iconify")
```

(De)iconify SAOImage/DS9:

```julia
SAOImageDS9.set("iconify", bool)
```

```julia
SAOImageDS9.set("lower")
SAOImageDS9.set("raise") # can be used to de-iconify
```

Get/set zoom level:
```julia
SAOImageDS9.get(Float64, "zoom")  # get current zoom level
SAOImageDS9.set("zoom", value)
SAOImageDS9.set("zoom to", value)
SAOImageDS9.set("zoom to fit")
```

Rotation:
```julia
SAOImageDS9.get(Float64, "rotate")
SAOImageDS9.set("rotate", value)
SAOImageDS9.set("rotate to", value)
SAOImageDS9.set("rotate open")
SAOImageDS9.set("rotate close")
```

```julia
SAOImageDS9.get(String, "orient")
SAOImageDS9.set("orient", value)
```

```julia
#iexam(;event::Union{AbstractString,Symbol}=:button) = get_words("iexam", event)

iexam(args...; event::Union{AbstractString,Symbol}=:button) =
    get_words("iexam", event, args...)

SAOImageDS9.get(Int, :threads)  # get threads
SAOImageDS9.set("threads", n)
```
