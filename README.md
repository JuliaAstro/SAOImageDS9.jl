# Julia interface to SAOImage/DS9

This [Julia](http://julialang.org/) package provides an interface to the image
viewer [SAOImage/DS9](http://ds9.si.edu/site/Home.html) via a
[Julia interface to the XPA Messaging System](https://github.com/emmt/XPA.jl).


## Prerequisites

To use this package, **DS9** program and **XPA.jl** package must be installed
on your computer.  If this is not the case, they are available for different
operating systems.  For example, on Ubuntu, just do:

    sudo apt-get install saods9 xpa-tools

Optionally, you may want to install [IPC.jl](https://github.com/emmt/IPC.jl)
package to benefit from shared memory.

In your Julia code/session, it is sufficient to do:

    import DS9

or:

    using DS9

which are equivalent as `DS9.jl` does not export any symbols.  Thus all
commands are prefixed by `DS9.`, if you prefer a different prefix, you can do
something like:

    const ds9 = DS9


## General syntax for the requests

The general syntax to issue a **set** request to the current DS9 access point
is:

    DS9.set(args...; data=nothing)

where `args...` are any number of arguments which will be automatically
converted in a string where the arguments are separated by spaces.  The keyword
`data` may be used to specify the data to send with the request, it may be
`nothing` (the default) or a Julia array.  For instance, the following 3
statements will set the current zoom to be equal to 3.7:

    DS9.set(:zoom,:to,3.7)
    DS9.set("zoom to",3.7)
    DS9.set("zoom to 3.7")

where the last line shows the string which is effectively sent to DS9 via the
`XPA.set` method.

The following methods can be used to issue a **get** request to the current DS9
access point depending on the expected type of result:

    DS9.get_bytes(args...)             -> buf
    DS9.get_text(args...)              -> str
    DS9.get_lines(args...; keep=false) -> arr
    DS9.get_words(args...)             -> arr

where `args...` are treated as for the `DS9.set` method.  The returned values
are respectively a vector of bytes, a single string (with the last end-of-line
removed if any), an array of strings (one for each line of the result and empty
line removed unless keyword `keep` is set `true`), or an array of (non-empty)
words.

If a single scalar integer or floating point is expected, two methods are
available:

    DS9.get_integer(args...)    -> scalar
    DS9.get_float(args...)      -> scalar

which return respectively an `Int` and a `Float64`.


## Display or retrieve an image

To display an image in DS9, do:

    DS9.set_data(arr)

where `arr` is a 2D or 3D Julia array.  If `arr` is a shared memory array
(provided by the [IPC.jl](https://github.com/emmt/IPC.jl) package), the shared
memory segment is directly used by DS9; otherwise, the contents of the array is
sent to DS9.  DS9 will display the data in the currently selected frame with
the current scale parameters, zoom, orientation, rotation, etc.

To retrieve the array displayed by the current DS9 frame, do:

    arr = DS9.get_data();


## Connection to a specific DS9 instance

By default, all requests are sent to the first DS9 instance found by the XPA
name server.  To send further requests to a specific DS9 instance, you may
do:

    DS9.connect(apt) -> ident

where `apt` is a string identifying a specific XPA access point.  The returned
value is the fully qualified identifier of the access point, it has the form
`host:port` for a TCP/IP socket or it is the path to the socket file for an
AF/Unix socket.  The access point `apt` may be a fully qualified identifier or
a template of the form `class:name` like `"DS9:*"` which corresponds to any
instance of the class `"DS9"`.  Note that `name` is the argument of the
`-title` option when DS9 is launched.  See
[XPA Template](http://hea-www.harvard.edu/RD/xpa/template.html) for a complete
description.

To retrieve the identifier of the current access point to DS9, you may call:

    DS9.connection()

Remember that all requests are sent to a given access point, but you may switch
between DS9 instances.  For instance:

    apt1 = DS9.connection()              # retrieve current access point
    apt2 = DS9.connect("DS9:some_name")  # second access point
    DS9.set_data(arr)                    # send an image to apt2
    DS9.connect(apt1);                   # switch to apt1
    DS9.zoom_to(1.4)                     # set zoom in apt1
    ...

When `DS9.jl` package is imported, it automatically connects to the first
access point matching `"DS9.*"` with a warning if no access points, or if more
than one access point are found.
