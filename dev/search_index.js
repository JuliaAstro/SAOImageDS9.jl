var documenterSearchIndex = {"docs": [

{
    "location": "#",
    "page": "Introduction",
    "title": "Introduction",
    "category": "page",
    "text": ""
},

{
    "location": "#Introduction-1",
    "page": "Introduction",
    "title": "Introduction",
    "category": "section",
    "text": "The DS9.jl package provides an interface between Julia and the image viewer SAOImage/DS9 via XPA.jl, a Julia interface to the XPA Messaging System."
},

{
    "location": "#Table-of-contents-1",
    "page": "Introduction",
    "title": "Table of contents",
    "category": "section",
    "text": "Pages = [\"install.md\", \"starting.md\", \"requests.md\", \"connect.md\", \"library.md\"]"
},

{
    "location": "#Method-index-1",
    "page": "Introduction",
    "title": "Method index",
    "category": "section",
    "text": ""
},

{
    "location": "install/#",
    "page": "Installation",
    "title": "Installation",
    "category": "page",
    "text": ""
},

{
    "location": "install/#Installation-1",
    "page": "Installation",
    "title": "Installation",
    "category": "section",
    "text": "To use this package, the SAOImage/DS9 program and the XPA dynamic library and headers must be installed on your computer.  If this is not the case, they are available for different operating systems.  For example, on Debian or Ubuntu-like Linux system, you can call apt-get from the command line:sudo apt-get install saods9 libxpa-devTo install the DS9.jl package, start Julia in interactive mode and do:using Pkg\nPkg.clone(\"https://github.com/emmt/DS9.jl\")Don\'t be feared with the warning message about using deprecated Pkg.clone instead of Pkg.add, as of Julia 1.0, Pkg.add(\"https://github.com/emmt/DS9.jl\") does not work in spite of what said the Julia documentation...See XPA.jl site for instructions about how to install this package if the installation of DS9.jl fails to properly install this required package.To upgrade the DS9.jl package:Pkg.update(\"DS9\")There is nothing to build."
},

{
    "location": "starting/#",
    "page": "Starting",
    "title": "Starting",
    "category": "page",
    "text": ""
},

{
    "location": "starting/#Starting-1",
    "page": "Starting",
    "title": "Starting",
    "category": "section",
    "text": "In your Julia code/session, it is sufficient to do:import DS9\nDS9.connect()or:using DS9\nDS9.connect()which are equivalent as DS9.jl does not export any symbols.  Thus all commands are prefixed by DS9., if you prefer a different prefix, you can do something like:const ds9 = DS9The DS9.connect call is needed to establish a connection to SAOImage/DS9 (which must be running).  With no arguments, DS9.connect chooses the first available server matching \"DS9:*\".  It is possible to specify an argument to DS9.connect to choose a given server.If you only want to connect to SAOImage/DS9 if no connections have already been established:if DS9.accesspoint() == \"\"\n    DS9.connect()\nendTo check the connection to SAOImage/DS9, you can type:DS9.get(VersionNumber)which should gives you the version of the SAOImage/DS9 to which you are connected."
},

{
    "location": "requests/#",
    "page": "SAOImage/DS9 requests",
    "title": "SAOImage/DS9 requests",
    "category": "page",
    "text": ""
},

{
    "location": "requests/#SAOImage/DS9-requests-1",
    "page": "SAOImage/DS9 requests",
    "title": "SAOImage/DS9 requests",
    "category": "section",
    "text": "There are two kinds of requests: get requests to retrieve some information or data from SAOImage/DS9 and set requests to send some data to SAOImage/DS9 or to set some of its parameters."
},

{
    "location": "requests/#Set-requests-1",
    "page": "SAOImage/DS9 requests",
    "title": "Set requests",
    "category": "section",
    "text": "The general syntax to perform a set request to the current SAOImage/DS9 access point is:DS9.set(args...; data=nothing)where args... are any number of arguments which will be automatically converted in a string where the arguments are separated by spaces.  The keyword data may be used to specify the data to send with the request, it may be nothing (the default) or a Julia array.  For instance, the following 3 calls will set the current zoom to be equal to 3.7:DS9.set(:zoom,:to,3.7)\nDS9.set(\"zoom to\",3.7)\nDS9.set(\"zoom to 3.7\")where the last line shows the string which is effectively sent to SAOImage/DS9 via the XPA.set method in the 3 above cases.As a special case, args... can be a single array to send to SAOImage/DS9 for being displayed:DS9.set(arr)where arr is a 2D or 3D Julia array.  SAOImage/DS9 will display the values of arr as an image (if arr is a 2D array) or a sequence of images (if arr is a 3D array) in the currently selected frame with the current scale parameters, zoom, orientation, rotation, etc.  Keyword order can be used to specify the byte ordering.  Keyword new can be set true to display the image in a new SAOImage/DS9 frame."
},

{
    "location": "requests/#Get-requests-1",
    "page": "SAOImage/DS9 requests",
    "title": "Get requests",
    "category": "section",
    "text": "To perform a get request, the general syntax is:DS9.get([T, [dims,]] args...)where the args... arguments are treated as for the DS9.set method (that is converted into a single text string with separating spaces).  Optional arguments T and dims are to specify the type of the expected result and, possibly, its list of dimensions.If neither T nor dims are specified, the result of the DS9.get(args...) call is an instance of XPA.Reply (see documentation about XPA.jl package for how to deal with the contents of such an instance).The following methods can be used to issue a get request to the current DS9 access point depending on the expected type of result:DS9.get(Vector{UInt8}, args...)         -> buf\nDS9.get(String, args...)                -> str\nDS9.get(Vector{String}, args...;\n        delim=isspace, keepempty=false) -> arr\nDS9.get(Tuple{Vararg{String}}, args...;\n        delim=isspace, keepempty=false) -> tupwhere args... are treated as for the DS9.set method.  The returned values are respectively a vector of bytes, a single string (with the last end-of-line removed if any), an array of strings (one for each line of the result and empty line removed unless keyword keepempty is set true), or an array of (non-empty) words.If a single scalar integer or floating point is expected, two methods are available:DS9.get(Int, args...)    -> scalar\nDS9.get(Float, args...)  -> scalarwhich return respectively an Int and a Float64.To retrieve the array displayed by the current SAOImage/DS9 frame, do:arr = DS9.get(Array);Keyword order can be used to specify the byte ordering."
},

{
    "location": "connect/#",
    "page": "Connection to a specific server",
    "title": "Connection to a specific server",
    "category": "page",
    "text": ""
},

{
    "location": "connect/#Connection-to-a-specific-server-1",
    "page": "Connection to a specific server",
    "title": "Connection to a specific server",
    "category": "section",
    "text": "When DS9.connect() is called without any argument, all subsequent requests will be sent to the first SAOImage/DS9 instance found by the XPA name server. To send further requests to a specific SAOImage/DS9 server, you may do:DS9.connect(apt) -> identwhere apt is a string identifying a specific XPA access point.  The returned value is the fully qualified identifier of the access point, it has the form host:port for a TCP/IP socket or it is the path to the socket file for an AF/Unix socket.  The access point apt may be a fully qualified identifier or a template of the form class:name like \"DS9:*\" which corresponds to any server of the class \"DS9\".  Note that name is the argument of the -title option when SAOImage/DS9 is launched.  See XPA Template for a complete description.  When DS9.connect() is called with no arguments or with a template containing wild characters, it automatically connects to the first access point matching the template (\"DS9.*\" by default) with a warning if no access points, or if more than one access point are found.To retrieve the identifier of the current access point to SAOImage/DS9, you may call:DS9.accesspoint()which yields an empty string if there are no current connection.Remember that all requests are sent to a given access point, but you may switch between SAOImage/DS9 servers.  For instance:apt1 = DS9.accesspoint()             # retrieve current access point\napt2 = DS9.connect(\"DS9:some_name\")  # second access point\nDS9.set(arr)                         # send an image to apt2\nDS9.connect(apt1);                   # switch to apt1\nDS9.set(\"zoom to\", 1.4)              # set zoom in apt1"
},

{
    "location": "library/#",
    "page": "Package library",
    "title": "Package library",
    "category": "page",
    "text": ""
},

{
    "location": "library/#Package-library-1",
    "page": "Package library",
    "title": "Package library",
    "category": "section",
    "text": ""
},

{
    "location": "library/#DS9.get",
    "page": "Package library",
    "title": "DS9.get",
    "category": "function",
    "text": "DS9.get([T, [dims,]] args...)\n\nsends a \"get\" request to the SAOImage/DS9 server.  The request is made of arguments args... converted into strings and merged with separating spaces. An exception is thrown in case of error.\n\nThe returned value depends on the optional arguments T and dims:\n\nIf neither T nor dims are specified, an instance of XPA.Reply is returned with at most one answer (see XPA.get for more details).\nIf only T is specified, it can be:\nString to return the answer as a single string;\nVector{String}} or Tuple{Vararg{String}} to return the answer split in words as a vector or as a tuple of strings;\nT where T<:Real to return a value of type T obtained by parsing the textual answer.\nTuple{Vararg{T}} where T<:Real to return a value of type T obtained by parsing the textual answer;\nVector{T} where T is not String to return the binary contents of the answer as a vector of type T;\nIf both T and dims are specified, T can be an array type like Array{S} or Array{S,N} and dims a list of N dimensions to retrieve the binary contents of the answer as an array of type Array{S,N}.\n\nAs a special case:\n\nDS9.get(Array; endian=:native) -> arr\n\nyields the contents of current SAOImage/DS9 frame as an array (or as nothing if the frame is empty). Keyword endian can be used to specify the byte order of the received values (see DS9.byte_order.\n\nTo retrieve the version of the SAOImage/DS9 program:\n\nDS9.get(VersionNumber)\n\nSee also DS9.connect, DS9.set and XPA.get.\n\n\n\n\n\n"
},

{
    "location": "library/#DS9.set",
    "page": "Package library",
    "title": "DS9.set",
    "category": "function",
    "text": "DS9.set(args...; data=nothing)\n\nsends command and/or data to the SAOImage/DS9 server.  The command is made of arguments args... converted into strings and merged with a separating spaces. Keyword data can be used to specify the data to send.  An exception is thrown in case of error.\n\nAs a special case:\n\nDS9.set(arr; mask=false, new=false, endian=:native)\n\nset the contents of the current SAOImage/DS9 frame to be array arr.  Keyword new can be set true to create a new frame for displyaing the array.  Keyword endian can be used to specify the byte order of the values in arr (see DS9.byte_order.\n\nSee also DS9.connect, DS9.get and XPA.set.\n\n\n\n\n\n"
},

{
    "location": "library/#Requests-to-SAOImage/DS9-1",
    "page": "Package library",
    "title": "Requests to SAOImage/DS9",
    "category": "section",
    "text": "DS9.getDS9.set"
},

{
    "location": "library/#DS9.connect",
    "page": "Package library",
    "title": "DS9.connect",
    "category": "function",
    "text": "DS9.connect(apt=\"DS9:*\") -> ident\n\nset the access point for further SAOImage/DS9 commands.  Argument apt identifies the XPA access point, it can be a template string like \"DS9:*\" which is the default value.  The returned value is the name of the access point.\n\nTo retrieve the name of the current SAOImage/DS9 access point, call the DS9.connection method.\n\nSee also DS9.accesspoint and DS9.connection.\n\n\n\n\n\n"
},

{
    "location": "library/#DS9.accesspoint",
    "page": "Package library",
    "title": "DS9.accesspoint",
    "category": "function",
    "text": "DS9.accesspoint()\n\nyields the XPA access point which identifies the SAOImage/DS9 server.  This access point can be set by calling the DS9.connection method.  An empty string is returned if no access point has been chosen.  To automatically connect to SAOImage/DS9 if not yet done, you can do:\n\nif DS9.accesspoint() == \"\"; DS9.connect(); end\n\nSee also DS9.connect and DS9.connection.\n\n\n\n\n\n"
},

{
    "location": "library/#DS9.connection",
    "page": "Package library",
    "title": "DS9.connection",
    "category": "function",
    "text": "DS9.connection()\n\nyields the XPA persistent client connection used to communicate with SAOImage/DS9 server(s).\n\nSee also DS9.accesspoint, DS9.connect and XPA.Client.\n\n\n\n\n\n"
},

{
    "location": "library/#Connection-1",
    "page": "Package library",
    "title": "Connection",
    "category": "section",
    "text": "DS9.connectDS9.accesspointDS9.connection"
},

{
    "location": "library/#DS9.bitpix_of",
    "page": "Package library",
    "title": "DS9.bitpix_of",
    "category": "function",
    "text": "DS9.bitpix_of(x) -> bp\n\nyields FITS bits-per-pixel (BITPIX) value for x which can be an array or a type.  A value of 0 is returned if x is not of a supported type.\n\nSee also DS9.bitpix_to_type.\n\n\n\n\n\n"
},

{
    "location": "library/#DS9.bitpix_to_type",
    "page": "Package library",
    "title": "DS9.bitpix_to_type",
    "category": "function",
    "text": "DS9.bitpix_to_type(bp) -> T\n\nyields Julia type corresponding to FITS bits-per-pixel (BITPIX) value bp. The value Nothing is returned if bp is unknown.\n\nSee also DS9.bitpix_of.\n\n\n\n\n\n"
},

{
    "location": "library/#DS9.byte_order",
    "page": "Package library",
    "title": "DS9.byte_order",
    "category": "function",
    "text": "DS9.byte_order(endian)\n\nyields the byte order for retrieving the elements of a SAOImage/DS9 array. Argument can be one of the strings (or the equivalent symbol): \"big\" for most significant byte first, \"little\" for least significant byte first or \"native\" to yield the byte order of the machine.\n\nSee also DS9.get, DS9.set.\n\n\n\n\n\n"
},

{
    "location": "library/#Utilities-1",
    "page": "Package library",
    "title": "Utilities",
    "category": "section",
    "text": "DS9.bitpix_ofDS9.bitpix_to_typeDS9.byte_order"
},

]}
