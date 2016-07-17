#
# DS9.jl --
#
# Implement communication with SAOImage DS9 (http://ds9.si.edu) via the XPA
# protocol.
#
#------------------------------------------------------------------------------
#
# This file is part of DS9.jl released under the MIT "expat" license.
# Copyright (C) 2016, Éric Thiébaut (https://github.com/emmt).
#
module DS9

warning(msg...) = print_with_color(:yellow, STDERR, "WARNING: ", msg..., "\n")

using XPA
const HAVE_IPC = try
    using IPC
    true
catch e
    warning("module IPC not found, will not use shared memory")
    false
end

typealias PixelTypes Union{UInt8,Int16,Int32,Int64,Float32,Float64}
const PIXEL_TYPES = (UInt8, Int16, Int32, Int64, Float32, Float64)

_match(pat::AbstractString, str::AbstractString) = (pat == str)
_match(::Void, str::AbstractString) = true
_match(pat::Regex, str::AbstractString) = is_match(pat, str)

function search(;name::Union{Void,AbstractString,Regex}=nothing,
                user::Union{Void,AbstractString,Regex}=ENV["USER"],
                access::Integer=0)
    access = UInt(access) & (XPA.GET|XPA.SET|XPA.INFO)
    for apt in xpa_list()
        apt.class == "DS9" || continue
        (apt.access & access) == access || continue
        _match(name, apt.name) || continue
        _match(user, apt.user) || continue
        return apt.addr
    end
    nothing
end

# Private variables to store current DS9 access point and XPA connection.
_DS9 = ""
_XPA = XPA.NullHandle

"""
   DS9.connect(apt="DS9:*") -> ident

set DS9 access point for further DS9 commands.  Argument `apt` identifies the
access point, it can be a template string like "DS9:*" which is the default
value.  The returned value is the name of the access point.

To retrieve the name of the current DS9 access point, do:

   DS9.connection() -> currentname
"""
function connect(apt::AbstractString="DS9:*")
    global _DS9, _XPA
    if _XPA == XPA.NullHandle
        _XPA = xpa_open()
    end
    cnt = 0
    for (data, name, mesg) in xpa_get(apt, "version"; xpa=_XPA, nmax=-1)
        length(mesg) > 0 && continue # ignore errors
        cnt += 1
        if cnt == 1
            _DS9 = split(name)[end]
        end
    end
    if cnt > 1
        warning("more than one matching DS9 server found, ",
                "the first one ($_DS9) was selected")
    elseif cnt == 0
        _DS9 = "DS9:*"
        warning("no matching DS9 server found, the default \"", _DS9,
                "\" will be used")
    end
    return _DS9
end

connection() = _DS9

@doc @doc(connect) connection

# establish the first connection
connect();

get_bytes(args...) = xpa_get_bytes(_DS9, args...; xpa=_XPA)

get_text(args...) = chomp(xpa_get_text(_DS9, args...; xpa=_XPA))

get_lines(args...; keep::Bool=false) =
    xpa_get_lines(_DS9, args...; xpa=_XPA, keep=keep)

get_words(args...) = xpa_get_words(_DS9, args...; xpa=_XPA)

get_integer(args...) = parse(Int, get_text(args...))

get_float(args...) = parse(Float64, get_text(args...))

get_integers(args...) = _parse_as_tuple(Int, get_words(args...))

get_floats(args...) = _parse_as_tuple(Float64, get_words(args...))

_parse_as_tuple{T}(::Type{T}, list) =
    ntuple(i->parse(T, list[i]), length(list))

set(args...; data::Union{Void,DenseArray}=nothing) =
    (xpa_set(_DS9, args...; xpa=_XPA, check=true, data=data); nothing)

about() = get_text("about")

version() = get_text("version")

exit() = set("exit")  # FIXME: should reconnect...

iconify() = yesorno(get_text("iconify"))

iconify(value::Bool) = iconify(yesorno(value))

iconify(value::Union{Symbol,AbstractString}) =
    set("iconify", value)

lower() = set("lower")

raise() = set("raise")

zoom() = get_float("zoom")

zoom(value::Real) = set("zoom", value)

zoom_to(value::Real) = set("zoom to", value)

zoom_to_fit() = set("zoom to fit")

rotate() = get_float("rotate")

rotate(value::Real) = set("rotate", value)

rotate_to(value::Real) = set("rotate to", value)

rotate_open() = set("rotate open")

rotate_close() = set("rotate close")

orient() = get_text("orient")

orient(value::Union{AbstractString,Symbol}) = set("orient", value)

#iexam(;event::Union{AbstractString,Symbol}=:button) = get_words("iexam", event)

iexam(args...; event::Union{AbstractString,Symbol}=:button) =
    get_words("iexam", event, args...)

get_threads() = get_integer(:threads)
set_threads(n::Integer) = set(:threads, n)

function guiwidth end
function guiheight end


"""
To retrieve the dimensions of the GUI:

    DS9.guiwidth()  -> width
    DS9.guiheight() -> height

To set the dimensions of the GUI:

    DS9.guiwidth(width)   -> width
    DS9.guiheight(height) -> height

"""
guiwidth

@doc @doc(guiwidth) guiheight

for s in ("width", "height")
    f = symbol(:gui, s)
    @eval begin
        $f() = get_integer($s)
        function $f(value::Integer)
            value::Int = value
            set($s, value)
            return value
        end
    end

end

"""
# Get DS9 frame settings

    DS9.getframe(           # returns the id of the current frame
    DS9.getframe("frameno") # returns the id of the current frame
    DS9.getframe("all")     # returns the id of all frames
    DS9.getframe("active")  # returns the id of all active frames
    DS9.getframe("lock")
    DS9.getframe("has","amplifier")
    DS9.getframe("has","datamin")
    DS9.getframe("has","datasec")
    DS9.getframe("has","detector")
    DS9.getframe("has","grid")
    DS9.getframe("has","iis")
    DS9.getframe("has","irafmin")
    DS9.getframe("has","physical")
    DS9.getframe("has","smooth")
    DS9.getframe("has","contour")
    DS9.getframe("has","contour","aux")
    DS9.getframe("has","fits")
    DS9.getframe("has","fits","bin")
    DS9.getframe("has","fits","cube")
    DS9.getframe("has","fits","mosaic")
    DS9.getframe("has","marker","highlite")
    DS9.getframe("has","marker","paste")
    DS9.getframe("has","marker","select")
    DS9.getframe("has","marker","undo")
    DS9.getframe("has","system","physical")
    DS9.getframe("has","wcs","wcsa")
    DS9.getframe("has","wcs","equatorial","wcsa")
    DS9.getframe("has","wcs","linear","wcsa")

"""
getframe(args...) = get_words("frame", args...)

currentframe() = get_integer("frame")

framehas(what...) = yesorno(get_text("frame", "has", what...))

"""
# Set DS9 frame settings

    DS9.setframe("center")         # center current frame
    DS9.setframe("center",1)       # center 'Frame1'
    DS9.setframe("center","all")   # center all frames
    DS9.setframe("clear")          # clear current frame
    DS9.setframe("new")            # create new frame
    DS9.setframe("new","rgb")      # create new rgb frame
    DS9.setframe("delete")         # delete current frame
    DS9.setframe("reset")          # reset current frame
    DS9.setframe("refresh")        # refresh current frame
    DS9.setframe("hide")           # hide current frame
    DS9.setframe("show",1)         # show frame 'Frame1'
    DS9.setframe("move","first")   # move frame to first in order
    DS9.setframe("move","back")    # move frame back in order
    DS9.setframe("move","forward") # move frame forward in order
    DS9.setframe("move","last")    # move frame to last in order
    DS9.setframe("first")          # goto first frame
    DS9.setframe("prev")           # goto prev frame
    DS9.setframe("next")           # goto next frame
    DS9.setframe("last")           # goto last frame
    DS9.setframe("frameno",4)      # goto frame 'Frame4',create if needed
    DS9.setframe(3)                # goto frame 'Frame3',create if needed
    DS9.setframe("match","wcs")
    DS9.setframe("lock","wcs")
"""
setframe(args...) = set("frame", args...)

firstframe() = setframe("first")
lastframe() = setframe("last")

doc"""
# get DS9 frame data

    DS9.get_data(;endian=:native) -> arr

yields the contents of current DS9 frame as an array (or as `nothing` if the
frame is empty).

"""
function get_data(; endian::Union{Symbol,AbstractString}=:native)
    typ = bitpix_to_type(get_bitpix())
    if typ === Void; return nothing; end
    siz = get_size()
    buf = get_bytes("array", byteorder(endian))
    reshape(reinterpret(typ, buf), siz)
end

doc"""

    DS9.set_data(arr; mask=false, new=false, endian=:native)

set contents of current DS9 frame to be array `arr`.
"""
function set_data{T<:PixelTypes,N}(arr::DenseArray{T,N};
                                   endian::Symbol=:native,
                                   mask::Bool=false,
                                   new::Bool=false)
    args = Array(ASCIIString, 0)
    push!(args, "array")
    if new; push!(args, "new"); end
    if mask; push!(args, "mask"); end
    set(args..., arraydescriptor(arr; endian=endian); data=arr)
end

if HAVE_IPC
    function set_data{T<:PixelTypes,N}(arr::ShmArray{T,N};
                                       endian::Symbol=:native)
        set("shm", "array", "shmid", shmid(arr),
            arraydescriptor(arr; endian=endian))
    end
end

function arraydescriptor{T,N}(arr::DenseArray{T,N}; endian::Symbol=:native)
    error("only 2D and 3D arrays are supported")
end

function arraydescriptor{T}(arr::DenseArray{T,2}; endian::Symbol=:native)
    bp = bitpixof(T)
    bp != 0 || error("unsupported data type")
    string("[xdim=",size(arr,1),",ydim=",size(arr,2),
           ",bitpix=",bp,",endian=",endian,"]")
end

function arraydescriptor{T}(arr::DenseArray{T,3}; endian::Symbol=:native)
    bp = bitpixof(T)
    bp != 0 || error("unsupported data type")
    string("[xdim=",size(arr,1),",ydim=",size(arr,2),",zdim=",size(arr,3),
           ",bitpix=",bp,",endian=",endian,"]")
end

"""
The following calls retrieve parameters of data in current DS9 frame:

    DS9.get_bitpix() -> bitpix
    DS9.get_width()  -> width
    DS9.get_height() -> height
    DS9.get_depth()  -> depth
    DS9.get_size()   -> dims
    DS9.get_size(n)  -> nth_dims
"""
function get_bitpix end

for field in ("bitpix", "width", "height", "depth")
    func = symbol(:get_,field)
    @eval function $func()
        str = get_text("fits", $field)
        length(str) > 0 ? parse(Int, str) : 0
    end
end

get_size() = get_integers("fits size")

function trueorfalse(str::AbstractString)
    str == "true"  ? true  :
    str == "false" ? false :
    throw(ArgumentError("expecting \"true\" or \"false\""))
end

function yesorno(str::AbstractString)
    str == "yes" ? true  :
    str == "no"  ? false :
    throw(ArgumentError("expecting \"yes\" or \"no\""))
end

yesorno(flag::Bool) = (flag ? "yes" : "no")
trueorfalse(flag::Bool) = (flag ? "true" : "false")

doc"""
    DS9.bitpixof(x)

yields FITS bits-per-pixel (BITPIX) value for `x` which can be an array or
a type.  A value of 0 is returned if `x` is not of a supported type.
"""
function bitpixof end
bitpixof{T,N}(::DenseArray{T,N}) = bitpixof(T)
for T in PIXEL_TYPES
    bp = (T <: Integer ? 8 : -8)*sizeof(T)
    @eval bitpixof(::Type{$T}) = $bp
    @eval bitpixof(::$T) = $bp
end
bitpixof(::Any) = 0

bitpix_to_type(bitpix::Int) =
    bitpix ==   8 ? UInt8   :
    bitpix ==  16 ? Int16   :
    bitpix ==  32 ? Int32   :
    bitpix ==  64 ? Int64   :
    bitpix == -32 ? Float32 :
    bitpix == -64 ? Float64 :
    Void
bitpix_to_type(bitpix::Integer) = bitpix_to_type(Int(bitpix))
bitpix_to_type(::Any) = Void

function fetchint(str::AbstractString,
                  prefix::AbstractString="")
    offset = length(prefix)
    if offset > 0 && ! startswith(str, prefix)
        error("string does not match prefix")
    end
    if length(str) ≤ offset
        error("short string")
    end
    parse(Int, str[1+offset:end])
end

function byteorder(endian::Symbol)
    endian == :native ? (ENDIAN_BOM == 0x01020304 ? "big" :
                         ENDIAN_BOM == 0x04030201 ? "little" :
                         error("unknown byte order")) :
    endian == :big ? "big" :
    endian == :little ? "little" :
    error("invalid byte order")
end

function byteorder(endian::AbstractString)
    endian == "native" ? (ENDIAN_BOM == 0x01020304 ? "big" :
                          ENDIAN_BOM == 0x04030201 ? "little" :
                          error("unknown byte order")) :
    endian == "big" || endian == "little" ? endian :
    error("invalid byte order")
end

end # module
