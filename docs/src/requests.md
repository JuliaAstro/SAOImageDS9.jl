# SAOImage/DS9 requests

There are two kinds of requests: **get** requests to retrieve some information or data
from SAOImage/DS9 and **set** requests to send some data to SAOImage/DS9 or to set some of
its parameters.


## Set requests

The general syntax to perform a **set** request to the current SAOImage/DS9
access point is:

```julia
ds9set(args...; data=nothing)
```

where `args...` are any number of arguments which will be automatically converted into a
string where the elements of `args...` are separated by a single space. The `data` keyword
may be used to specify the data to send with the request, it may be `nothing` (the
default) or a Julia array. For instance, the following 3 calls will set the current zoom
to be equal to 3.7:

```julia
ds9set(:zoom, :to, 3.7)
ds9set("zoom to", 3.7)
ds9set("zoom to 3.7")
```

where the last line shows the string which is effectively sent to SAOImage/DS9 via the
`XPA.set` method in the 3 above cases.

As a special case, `args...` can be a single array to send to SAOImage/DS9 for being
displayed:

```julia
ds9set(arr)
```

where `arr` is a 2D or 3D Julia array. SAOImage/DS9 will display the values of `arr` as an
image (if `arr` is a 2D array) or a sequence of images (if `arr` is a 3D array) in the
currently selected frame with the current scale parameters, zoom, orientation, rotation,
etc. Keyword `order` can be used to specify the byte ordering. Keyword `new` can be set
true to display the image in a new SAOImage/DS9 frame. FIXME


## Get requests

To perform a **get** request, the general syntax is:

```julia
ds9get([T, [dims,]] args...)
```

where the `args...` arguments are treated as for the `ds9set` method
(that is converted into a single text string with separating spaces).  Optional
arguments `T` and `dims` are to specify the type of the expected result and,
possibly, its list of dimensions.

If neither `T` nor `dims` are specified, the result of the
`ds9get(args...)` call is an instance of `XPA.Reply` (see
documentation about XPA.jl package for how to deal with the contents of such an
instance).

The following methods can be used to issue a **get** request to the current DS9
access point depending on the expected type of result:

```julia
ds9get(Vector{UInt8}, args...)         -> buf
ds9get(String, args...)                -> str
ds9get(Vector{String}, args...;
                delim=isspace, keepempty=false) -> arr
ds9get(Tuple{Vararg{String}}, args...;
                delim=isspace, keepempty=false) -> tup
```

where `args...` are treated as for the `ds9set` method.  The returned
values are respectively a vector of bytes, a single string (with the last
end-of-line removed if any), an array of strings (one for each line of the
result and empty line removed unless keyword `keepempty` is set `true`), or an
array of (non-empty) words.

If a single scalar integer or floating point is expected, two methods are
available:

```julia
ds9get(Int, args...)    -> scalar
ds9get(Float, args...)  -> scalar
```

which return respectively an `Int` and a `Float64`.

To retrieve the array displayed by the current SAOImage/DS9 frame, do:

```julia
arr = ds9get(Array);
```

Keyword `order` can be used to specify the byte ordering.
