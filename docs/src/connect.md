# Connection to a specific server

When `DS9.connect()` is called without any argument, all subsequent requests
will be sent to the first SAOImage/DS9 instance found by the XPA name server.
To send further requests to a specific SAOImage/DS9 server, you may do:

```julia
DS9.connect(apt) -> ident
```

where `apt` is a string identifying a specific XPA access point.  The returned
value is the fully qualified identifier of the access point, it has the form
`host:port` for a TCP/IP socket or it is the path to the socket file for an
AF/Unix socket.  The access point `apt` may be a fully qualified identifier or
a template of the form `class:name` like `"DS9:*"` which corresponds to any
server of the class `"DS9"`.  Note that `name` is the argument of the `-title`
option when SAOImage/DS9 is launched.  See [XPA
Template](http://hea-www.harvard.edu/RD/xpa/template.html) for a complete
description.  When `DS9.connect()` is called with no arguments or with a
template containing wild characters, it automatically connects to the first
access point matching the template (`"DS9.*"` by default) with a warning if no
access points, or if more than one access point are found.

To retrieve the identifier of the current access point to SAOImage/DS9, you may call:

```julia
DS9.accesspoint()
```

which yields an empty string if there are no current connection.

Remember that all requests are sent to a given access point, but you may switch
between SAOImage/DS9 servers.  For instance:

```julia
apt1 = DS9.accesspoint()             # retrieve current access point
apt2 = DS9.connect("DS9:some_name")  # second access point
DS9.set(arr)                         # send an image to apt2
DS9.connect(apt1);                   # switch to apt1
DS9.set("zoom to", 1.4)              # set zoom in apt1
```
