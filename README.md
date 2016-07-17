# Julia interface to SAOImage/DS9

This [Julia](http://julialang.org/) package provides an interface to the image
viewer [SAOImage/DS9](http://ds9.si.edu/site/Home.html) via the
[XPA Messaging System](https://github.com/ericmandel/xpa).

**Caveat:** This package is quite young and many utility methods (not
  documented here) are subject to change until I find a consistent naming
  convention.  Documented methods like `DS9.set`, `DS9.set_data`,
  `DS9.get_bytes`, `DS9.get_data`, *etc.* will however remain, so you can count
  on them.


## Prerequisites

To use this package, **DS9** and **XPA** must be installed on your computer.
If this is not the case, they are available for different operating systems.
For example, on Ubuntu, just do:

    sudo apt-get install saods9

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

The general syntax to issue a **set** request to the current DS9 access point is:

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
`xpa_set` method.

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


## Using the XPA Message System

Julia interface to SAOImage/DS9 is built on top of the XPA Message System by
Eric Mandel.  For now, only a subset of the client routines has been interfaced
with Julia.  The interface exploits the power of `ccall` to directly call the
routines of the compiled XPA library.  The implemented methods are described in
what follows, more extensive XPA documentation can be found
[here](http://hea-www.harvard.edu/RD/xpa/help.html).


### Get data

The method:

    xpa_get(src [, params...]) -> tup

retrieves data from one or more XPA access points identified by `src` (a
template name, a `host:port` string or the name of a Unix socket file) with
parameters `params...` (automatically converted into a single string where the
parameters are separated by a single space).  The result is a tuple of tuples
`(data,name,mesg)` where `data` is a vector of bytes (`UInt8`), `name` is a
string identifying the server which answered the request and `mesg` is an error
message (a zero-length string `""` if there are no errors).

The following keywords are accepted:

* `nmax` specifies the maximum number of answers, `nmax=1` by default.
  Use `nmax=-1` to use the maximum number of XPA hosts.

* `xpa` specifies an XPA handle (created by `xpa_open`) for faster connections.

* `mode` specifies options in the form `"key1=value1,key2=value2"`.


There are simpler methods which return only the data part of the answer,
possibly after conversion.  These methods limit the number of answers to be at
most one and throw an error if `xpa_get` returns a non-empty error message.  To
retrieve the `data` part of the answer received by an `xpa_get` request as a
vector of bytes, call the method:

    xpa_get_bytes(src [, params...]; xpa=..., mode=...) -> buf

where arguments `src` and `params...` and keywords `xpa` and `mode` are passed
to `xpa_get`.  To convert the result of `xpa_get_bytes` into a single string,
call the method:

    xpa_get_text(src [, params...]; xpa=..., mode=...) -> str

To split the result of `xpa_get_text` into an array of strings, one for each
line, call the method:

    xpa_get_lines(src [, params...]; keep=false, xpa=..., mode=...) -> arr

where keyword `keep` can be set `true` to keep empty lines.  Finally, to split
the result of `xpa_get_text` into an array of words, call the method:

    xpa_get_words(src [, params...]; xpa=..., mode=...) -> arr


### Send data or commands

The method:

    xpa_set(dest [, params...]; data=nothing) -> tup

send `data` to one or more XPA access points identified by `dest` with
parameters `params...` (automatically converted into a single string where the
parameters are separated by a single space).  The result is a tuple of tuples
`(name,mesg)` where `name` is a string identifying the server which received
the request and `mesg` is an error message (a zero-length string `""` if there
are no errors).

The following keywords are accepted:

* `data` the data to send, may be `nothing` or an array.  If it is an array, it
  must be an instance of a sub-type of `DenseArray` which implements the
  `pointer` method.

* `nmax` specifies the maximum number of answers, `nmax=1` by default.
  Use `nmax=-1` to use the maximum number of XPA hosts.

* `xpa` specifies an XPA handle (created by `xpa_open`) for faster connections.

* `mode` specifies options in the form `"key1=value1,key2=value2"`.

* `check` specifies whether to check for errors.  If this keyword is set
  `true`, an error is thrown for the first non-empty error message `mesg`
  encountered in the list of answers.


## Open a persistent client connection

The method:

    xpa_open() -> handle

returns a handle to an XPA persistent connection and which can be used as the
argument of the `xpa` keyword of the `xpa_get` and `xpa_set` methods to speed
up requests.  The persistent connection is automatically closed when the handle
is finalized by the garbage collector.


## Utilities

The method:

    xpa_list(; xpa=...) -> arr

returns a list of the existing XPA access points as an array of structured
elements:

    arr[i].class    # class of the access point
    arr[i].name     # name of the access point
    arr[i].addr     # socket address
    arr[i].user     # user name of access point owner
    arr[i].access   # allowed access (g=xpaget,s=xpaset,i=xpainfo)

all members but `access` are strings, the `addr` member is the name of the
socket used for the connection (either `host:port` for internet socket, or a
file path for local unix socket), `access` is a combination of the bits
`XPA.GET`, `XPA.SET` and/or `XPA.INFO` depending whether `xpa_get`, `xpa_set`
and/or `xpa_info` access are granted.  Note that `xpa_info` is not yet
implemented.

XPA messaging system can be configured via environment variables.  The
method `xpa_config` provides means to get or set XPA settings:

    xpa_config(key) -> val

yields the current value of the XPA parameter `key` which is one of:

    "XPA_MAXHOSTS"
    "XPA_SHORT_TIMEOUT"
    "XPA_LONG_TIMEOUT"
    "XPA_CONNECT_TIMEOUT"
    "XPA_TMPDIR"
    "XPA_VERBOSITY"
    "XPA_IOCALLSXPA"

The key may be a symbol or a string, the value of a parameter may be a boolean,
an integer or a string.  To set an XPA parameter, call the method:

    xpa_config(key, val) -> old

which returns the previous value of the parameter.
