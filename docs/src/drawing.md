# Drawing in SAOImage/DS9

`SAOImageDS9` can be used to quickly draw or display things in SAOImage/DS9.

For instance, assuming `img` is a 2-dimensional Julia array, to display `img`
as an image in SAOImage/DS9, call:

```julia
SAOImageDS9.draw(img; kwds...)
```

The main difference with `SAOImageDS9.set(img)` is that a number of keywords
are supported:

- Use keyword `frame` to specify the frame number.

- Use keyword `cmap` to specify the name of the colormap.  For instance,
  `cmap="gist_stern"`.

- Use keyword `zoom` to specify the zoom factor.

- Use keywords `min` and/or `max` to specify the scale limits.

The [`SAOImageDS9.draw`](@ref) method can be called with other kinds of
arguments such as instances (or array or tuple) of `TwoDimensional.Point` to
draw point(s) or instances of `TwoDimensional.BoundingBox` to draw
rectangle(s).
