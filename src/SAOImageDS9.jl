#
# SAOImageDS9.jl --
#
# Implement communication with SAOImage/DS9 (http://ds9.si.edu) via the XPA
# protocol.
#
#------------------------------------------------------------------------------
#
# This file is part of SAOImageDS9.jl released under the MIT "expat" license.
# Copyright (C) 2016-2020, Éric Thiébaut (https://github.com/emmt).
#

module SAOImageDS9

export DS9

const DS9 = SAOImageDS9

using XPA
using XPA: TupleOf, connection, join_arguments

using TwoDimensional

using Base: ENV
using Base.Iterators: Pairs

# FITS pixel types.
const PixelTypes = Union{UInt8,Int16,Int32,Int64,Float32,Float64}
const PIXELTYPES = (UInt8, Int16, Int32, Int64, Float32, Float64)

"""
    SAOImageDS9.accesspoint()

yields the XPA access point which identifies the SAOImage/DS9 server.  This
access point can be set by calling the [`SAOImageDS9.connect`](@ref) method.
An empty string is returned if no access point has been chosen.  To
automatically connect to SAOImage/DS9 if not yet done, you can do:

```julia
if SAOImageDS9.accesspoint() == ""
    SAOImageDS9.connect()
end
```

See also [`SAOImageDS9.connect`](@ref) and [`SAOImageDS9.accesspoint`](@ref).

""" accesspoint
const _ACCESSPOINT = Ref("")
accesspoint() = _ACCESSPOINT[]

# Same as `connection()` but attempt to automatically connect an access point
# has not yet been chosen.
function _apt() # @btime -> 3.706 ns (0 allocations: 0 bytes)
    apt = accesspoint()
    if apt == ""
        try
            apt = connect()
        catch err
            _warn("Failed to automatically connect to SAOImage/DS9.\n",
                  "Launch ds9 then do `ds9connect()`")
        end
    end
    return apt
end

"""
    SAOImageDS9.connect(ident="DS9:*") -> apt

set the access point for further SAOImage/DS9 commands.  Argument `ident`
identifies the XPA access point, it can be a template string like `"DS9:*"`
which is the default value or a regular expression.  The returned value is the
name of the access point.

To retrieve the name of the current SAOImage/DS9 access point, call the
[`SAOImageDS9.accesspoint`](@ref) method.

"""
function connect(ident::Union{Regex,AbstractString} = "DS9:*"; kwds...)
    apt = XPA.find(ident; kwds...)
    apt === nothing && error("no matching SAOImage/DS9 server found")
    rep = XPA.get(apt, "version"; nmax=1)
    if length(rep) != 1 || ! XPA.verify(rep)
        error("XPA server at address \"" * apt *
              "\" does not seem to be a SAOImage/DS9 server")
    end
    addr = XPA.address(apt)
    _ACCESSPOINT[] = addr
    return addr
end

_warn(args...) = printstyled(stderr, "WARNING: ", args..., "\n";
                             color=:yellow)

"""
    SAOImageDS9.get([T, [dims,]] args...)

sends a "get" request to the SAOImage/DS9 server.  The request is made of
arguments `args...` converted into strings and merged with separating spaces.
An exception is thrown in case of error.

The returned value depends on the optional arguments `T` and `dims`:

* If neither `T` nor `dims` are specified, an instance of `XPA.Reply` is
  returned with at most one answer (see documentation for `XPA.get` for more
  details).

* If only `T` is specified, it can be:

  * `String` to return the answer as a single string;

  * `Vector{String}}` or `Tuple{Vararg{String}}` to return the answer split in
    words as a vector or as a tuple of strings;

  * `T` where `T<:Real` to return a value of type `T` obtained by parsing the
    textual answer.

  * `Tuple{Vararg{T}}` where `T<:Real` to return a value of type `T` obtained
    by parsing the textual answer;

  * `Vector{T}` where `T` is not `String` to return the binary contents
    of the answer as a vector of type `T`;

* If both `T` and `dims` are specified, `T` can be an array type like
  `Array{S}` or `Array{S,N}` and `dims` a list of `N` dimensions to retrieve
  the binary contents of the answer as an array of type `Array{S,N}`.

As a special case:

    SAOImageDS9.get(Array; endian=:native) -> arr

yields the contents of current SAOImage/DS9 frame as an array (or as `nothing`
if the frame is empty). Keyword `endian` can be used to specify the byte order
of the received values (see [`SAOImageDS9.byte_order`](@ref)).

To retrieve the version of the SAOImage/DS9 program:

    SAOImageDS9.get(VersionNumber)

See also [`SAOImageDS9.connect`](@ref), [`SAOImageDS9.set`](@ref) and
`XPA.get`.

"""
get(args...) = XPA.get(_apt(), join_arguments(args); nmax=1, throwerrors=true)

# Yields result as a vector of numerical values extracted from the binary
# contents of the reply.
get(::Type{Vector{T}}, args...) where {T} =
    XPA.get(Vector{T}, _apt(), join_arguments(args); nmax=1, throwerrors=true)

# Idem with given number of elements.
get(::Type{Vector{T}}, dim::Integer, args...) where {T} =
    XPA.get(Vector{T}, (dim,), _apt(), join_arguments(args);
            nmax=1, throwerrors=true)

# Yields result as an array of numerical values with given dimensions
# and extracted from the binary contents of the reply.
get(::Type{Array{T,N}}, dims::NTuple{N,Integer}, args...) where {T,N} =
    XPA.get(Array{T,N}, dims, _apt(), join_arguments(args);
            nmax=1, throwerrors=true)

# Idem but Array number of dimensions not specified.
get(::Type{Array{T}}, dims::NTuple{N,Integer}, args...) where {T,N} =
    get(Array{T,N}, dims, args...)

# Yields result as a single string.
get(::Type{String}, args...) =
    XPA.get(String, _apt(), join_arguments(args); nmax=1, throwerrors=true)

# Yields result as a vector of strings split out of the textual contents of the
# reply.
function get(::Type{Vector{String}}, args...;
             delim = isspace,
             keepempty::Bool=false)
    return split(chomp(get(String, args...)), delim; keepempty=keepempty)
end

# Yields result as a tuple of strings split out of the textual contents of the
# reply.
get(::Type{TupleOf{String}}, args...; kdws...) =
    Tuple(get(Vector{String}, args...; kdws...))

# Yields result as a numerical value parsed from the textual contents of the
# reply.
function get(::Type{T}, args...) :: T where {T<:Real}
    _parse(T, get(String, args...))
end

# Yields result as a tuple of numerical values parsed from the textual contents
# of the reply.
get(::Type{TupleOf{T}}, args...) where {T<:Real} =
    _parse(TupleOf{T}, get(String, args...))

_parse(::Type{T}, str::AbstractString) where {T<:Real} = parse(T, str)

function _parse(::Type{Bool}, str::AbstractString)
    key = strip(str)
    haskey(_BOOLEANS, key) ||
        throw(ArgumentError("invalid boolean textual value"))
    return _BOOLEANS[key]
end

const _BOOLEANS = Dict{String,Bool}("true"  => true, "yes" => true,
                                    "false" => false, "no" => false)

function _parse(::Type{TupleOf{T}},
                list::TupleOf{AbstractString}) where {T<:Real}
    return map(s -> _parse(T, s), list)
end

function _parse(::Type{TupleOf{T}},
                str::AbstractString) where {T<:Real}
    return Tuple(map(s -> _parse(T, s), split(str; keepempty=false)))
end

function get(::Type{Array}; endian::Union{Symbol,AbstractString}=:native)
    T = bitpix_to_type(get(Int, "fits bitpix"))
    if T === Nothing; return nothing; end
    dims = get(TupleOf{Int}, "fits size")
    return get(Array{T}, dims, "array", byte_order(endian))
end

function get(::Type{VersionNumber})
    str = get(String, "version")
    m = match(r"^ds9 +([.0-9]+[a-z]*)\s*$", str)
    m === nothing && error("unknown version number in \"$str\"")
    return VersionNumber(m.captures[1])
end

"""
    SAOImageDS9.set(args...; data=nothing)

sends command and/or data to the SAOImage/DS9 server.  The command is made of
arguments `args...` converted into strings and merged with a separating spaces.
Keyword `data` can be used to specify the data to send.  An exception is thrown
in case of error.

As a special case:

    SAOImageDS9.set(arr; mask=false, new=false, endian=:native)

set the contents of the current SAOImage/DS9 frame to be array `arr`.  Keyword
`new` can be set true to create a new frame for displyaing the array.  Keyword
`endian` can be used to specify the byte order of the values in `arr` (see
[`SAOImageDS9.byte_order`](@ref).

See also [`SAOImageDS9.connect`](@ref), [`SAOImageDS9.get`](@ref) and
`XPA.set`.

"""
function set(args...; data=nothing)
    XPA.set(_apt(), join_arguments(args); nmax=1, throwerrors=true, data=data)
    return nothing
end

function set(arr::DenseArray{T,N};
             endian::Symbol=:native,
             mask::Bool=false,
             new::Bool=false) where {T<:PixelTypes,N}
    args = String[]
    push!(args, "array")
    if new; push!(args, "new"); end
    if mask; push!(args, "mask"); end
    set(args..., _arraydescriptor(arr; endian=endian); data=arr)
end

# Convert other pixel types.
for (T, S) in ((Int8,   Int16),
               (UInt16, Float32),
               (UInt32, Float32),
               (UInt64, Float32))
    @eval set(arr::AbstractArray{$T,N}; kwds...) where {N} =
        set(convert(Array{$S,N}, arr); kwds...)
end

# Convert non-dense array types.
for T in PIXELTYPES
    @eval set(arr::AbstractArray{$T,N}; kwds...) where {N} =
        set(convert(Array{$T,N}, arr); kwds...)
end

function _arraydescriptor(arr::DenseArray{T,2};
                          endian::Symbol=:native) where {T}
    bp = bitpix_of(T)
    bp != 0 || error("unsupported data type")
    return string("[xdim=",size(arr,1),",ydim=",size(arr,2),
                  ",bitpix=",bp,",endian=",endian,"]")
end

function _arraydescriptor(arr::DenseArray{T,3};
                          endian::Symbol=:native) where {T}
    bp = bitpix_of(T)
    bp != 0 || error("unsupported data type")
    return string("[xdim=",size(arr,1),",ydim=",size(arr,2),",zdim=",size(arr,3),
                  ",bitpix=",bp,",endian=",endian,"]")
end

_arraydescriptor(arr::DenseArray; kdws...) =
    error("only 2D and 3D arrays are supported")

"""
    SAOImageDS9.bitpix_of(x) -> bp

yields FITS bits-per-pixel (BITPIX) value for `x` which can be an array or a
type.  A value of 0 is returned if `x` is not of a supported type.

See also [`SAOImageDS9.bitpix_to_type`](@ref).

"""
bitpix_of(::DenseArray{T}) where {T} = bitpix_of(T)
for T in PIXELTYPES
    bp = (T <: Integer ? 8 : -8)*sizeof(T)
    @eval bitpix_of(::Type{$T}) = $bp
    @eval bitpix_of(::$T) = $bp
end
bitpix_of(::Any) = 0

"""
    SAOImageDS9.bitpix_to_type(bp) -> T

yields Julia type corresponding to FITS bits-per-pixel (BITPIX) value `bp`.
The value `Nothing` is returned if `bp` is unknown.

See also [`SAOImageDS9.bitpix_of`](@ref).

"""
bitpix_to_type(bitpix::Int) =
    (bitpix ==   8 ? UInt8   :
     bitpix ==  16 ? Int16   :
     bitpix ==  32 ? Int32   :
     bitpix ==  64 ? Int64   :
     bitpix == -32 ? Float32 :
     bitpix == -64 ? Float64 : Nothing)
bitpix_to_type(bitpix::Integer) = bitpix_to_type(Int(bitpix))
bitpix_to_type(::Any) = Nothing

"""
    SAOImageDS9.byte_order(endian)

yields the byte order for retrieving the elements of a SAOImage/DS9 array.
Argument can be one of the strings (or the equivalent symbol): `"big"` for most
significant byte first, `"little"` for least significant byte first or
`"native"` to yield the byte order of the machine.

See also [`SAOImageDS9.get`](@ref), [`SAOImageDS9.set`](@ref).

"""
byte_order(endian::Symbol) =
    (endian == :native ? (ENDIAN_BOM == 0x01020304 ? "big" :
                          ENDIAN_BOM == 0x04030201 ? "little" :
                          error("unknown byte order")) :
     endian == :big ? "big" :
     endian == :little ? "little" :
     error("invalid byte order"))

byte_order(endian::AbstractString) =
    (endian == "native" ? (ENDIAN_BOM == 0x01020304 ? "big" :
                           ENDIAN_BOM == 0x04030201 ? "little" :
                           error("unknown byte order")) :
     endian == "big" || endian == "little" ? endian :
     error("invalid byte order"))

#------------------------------------------------------------------------------
# DRAWING

"""
    SAOImageDS9.draw(args...; kwds...)

draws something in SAOImage/DS9 application.  The operation depends on the type
of the arguments.

---
    SAOImageDS9.draw(img; kwds...)

displays image `img` (a 2-dimensional Julia array) in SAOImage/DS9.
The following keywords are possible:

- Keyword `frame` can be used to specify the frame number.

- Keyword `cmap` can be used to specify the name of the colormap.  For
  instance, `cmap="gist_stern"`.

- Keyword `zoom` can be used to specify the zoom factor.

- Keywords `min` and/or `max` can be used to specify the scale limits.

---
    SAOImageDS9.draw(pnt; kwds...)

draws `pnt` as point(s) in SAOImage/DS9, `pnt` is a `Point`, an array or a
tuple of `Point`.

---
    SAOImageDS9.draw(box; kwds...)

draws `box` as rectangle(s) in SAOImage/DS9, `box` is a `BoundingBox`, an array
or a tuple of `BoundingBox`.

"""
draw(args...; kwds...) = draw(args; kwds...)
draw(::Tuple{}; kwds...) = nothing
draw(::T; kwds...) where {T} = error("unexpected type of argument(s): $T")

function draw(img::AbstractMatrix;
              min::Union{Real,Nothing} = nothing,
              max::Union{Real,Nothing} = nothing,
              cmap = nothing,
              frame = nothing,
              zoom = nothing)
    # FIXME: pack all commands into a single one.
    frame === nothing || ds9set("frame", frame)
    zoom === nothing || ds9set("zoom to", zoom)
    set(img)
    if min !== nothing || max !== nothing
        set("scale limits", limits(img, min, max)...)
    end
    cmap === nothing || set("cmap", cmap)
    return nothing
end

# For multiple points/circles/... we just send a command to SAOImage/DS9 for
# each item to draw.  Packing multiple commands (separated by semi-columns)
# does not really speed-up things and is more complicated because there is a
# limit to the total length of an XPA command (given by XPA.SZ_LINE I guess).

draw(A::Point; kwds...) = _draw(_region(Val(:point), kwds), A)
function draw(A::Union{Tuple{Vararg{Point}},
                       AbstractArray{<:Point}}; kwds...)
    cmd = _region(Val(:point), kwds)
    for i in eachindex(A)
        _draw(cmd, A[i])
    end
end

draw(A::BoundingBox; kwds...) =  _draw(_region(Val(:polygon), kwds), A)
function draw(A::Union{Tuple{Vararg{BoundingBox}},
                       AbstractArray{<:BoundingBox}}; kwds...)
    cmd = _region(Val(:polygon), kwds)
    for i in eachindex(A)
        _draw(cmd, A[i])
    end
end

function _draw(cmd::NTuple{2,AbstractString}, A::Point)
    set(cmd[1], A.x, A.y, cmd[2])
    nothing
end

function _draw(cmd::NTuple{2,AbstractString}, A::BoundingBox)
    x0, x1, y0, y1 = Tuple(A)
    set(cmd[1], x0, y0, x1, y0, x1, y1, x0, y1, x0, y0, cmd[2])
    nothing
end

_set_options(kwds::Pairs) = (isempty(kwds) ? "" :
                             throw(ArgumentError("unexpected argument")))

function _set_options(kwds::Pairs{Symbol})
    io = IOBuffer()
    print(io, " #")
    for (key, val) in kwds
        _set_option(io, key, val)
    end
    print(io, " }")
    return String(take!(io))
end

_set_option(io::IOBuffer, name::Union{Symbol,AbstractString}, value::Nothing) =
    nothing
_set_option(io::IOBuffer, name::Union{Symbol,AbstractString}, value) =
    print(io, " ", name, "=", value)
_set_option(io::IOBuffer, name::Union{Symbol,AbstractString}, value::Bool) =
    print(io, " ", name, (value ? "=1" : "=0"))

for id in (:circle, :ellipse, :box, :polygon, :point, :line,
           :vector, :text, :ruler, :compass, :projection, :annulus,
           :panda, :epanda, :bpanda)
    V = Val{id}
    cmd = "regions command { $id"
    @eval _region(::$V, kwds::Pairs) = ($cmd, _set_options(kwds))
end

"""
    SAOImageDS9.message([apt=SAOImageDS9.accesspoint(),] msg; cancel=false)

displays a message dialog with text `msg` in SAOImage/DS9 application referred
by `apt` and returns a boolean.  If keyword `cancel` is true, a *Cancel* button
is added to the dialog and `false` maybe returned if the dialog is not closed
by clicking the *OK* button; otherwise `true` is returned.

"""
message(msg::AbstractString; kwds...) =  message(_apt(), msg; kwds...)
function message(apt, msg::AbstractString; cancel::Bool = false)
    btn = (cancel ? "okcancel" : "ok")
    cmd = "analysis message $btn {$msg}"
    tryparse(Int, XPA.get(String, apt, cmd)) == 1
end

"""
    SAOImageDS9.select([apt=SAOImageDS9.accesspoint(),];
                       text="", key=false, cancel=false) -> (k,x,y,v)

returns the position selected by the user in SAOImage/DS9 application referred
by `apt`.  If keyword `text` is set, a dialog message is first displayed,
possibly with a *Cancel* button if keyword `cancel` is true.  If keyword `key`
is true, the position is selected by pressing a key; otherwise, the position is
selected by clicking the first mouse button.  The result is either `nothing`
(for instance if the *Cancel* button of the dialog is clicked) or a 4-tuple
`(k,x,y,v)` with `k` the pressed key (an empty string if `key` is false),
`(x,y)` are the coordinates of the selected position and `v` is the
corresponding value in the data.

"""
function select(apt = _apt();
                text::AbstractString = "",
                cancel::Bool = false,
                key::Bool = false)
    if length(text) > 0
        message(apt, text; cancel=cancel) || return nothing
    end
    cmd = (key ? "iexam key {\$x \$y \$value}" : "iexam {\$x \$y \$value}")
    rep = split(XPA.get(String, apt, cmd))
    off = (key ? 1 : 0)
    length(rep) == 3+off || return nothing
    k = (key ? string(rep[off+0]) : "")
    x = tryparse(Float64, rep[off+1])
    y = tryparse(Float64, rep[off+2])
    v = tryparse(Float64, rep[off+3])
    (x === nothing || y === nothing || v === nothing) && return nothing
    return k, x, y, v
end

#------------------------------------------------------------------------------
# LIMITS

"""
    limits(A, cmin=nothing, cmax=nothing) -> (lo, hi)

yields the clipping limits of values in array `A`.  The result is a 2-tuple of
double precision floats `(lo,hi)`.  If `cmin` is `nothing`, `lo` is the minimal
finite value found in `A` and converted to `Cdouble`; otherwise `lo =
Cdouble(cmin)`.  If `cmax` is `nothing`, `hi` is the maximal finite value found
in `A` and converted to `Cdouble`; otherwise `hi = Cdouble(cmax)`.

"""
limits(A::AbstractArray{<:Real}, ::Nothing, ::Nothing) =
    to_limits(finite_extrema(A))

limits(A::AbstractArray{<:Real}, cmin::Real, ::Nothing) =
    to_limits(cmin, finite_maximum(A))

limits(A::AbstractArray{<:Real}, ::Nothing, cmax::Real) =
    to_limits(finite_minimum(A), cmax)

limits(A::AbstractArray{<:Real}, cmin::Real, cmax::Real) =
    to_limits(cmin, cmax)

to_limits(c::Tuple{Real,Real}) = to_limits(c...)
to_limits(cmin::Cdouble, cmax::Cdouble) = (cmin, cmax)
to_limits(cmin::Real, cmax::Real) = to_limits(convert(Cdouble, cmin),
                                              convert(Cdouble, cmax))

"""
    finite_extrema(A) -> (vmin, vmax)

yields the minimum and maximum finite values in array `A`.  The result is such
that `vmin ≤ vmax` (both values being finite) unless there are no finite values
in `A` in which case `vmin > vmax`.

"""
finite_extrema(A::AbstractArray{<:Real}) = valid_extrema(isfinite, A)

"""
    finite_minimum(A) -> vmin

yields the minimum finite value in array `A`.  The result is never a NaN but
may be `typemax(eltype(A))` if there are no finite values in `A`.

"""
finite_minimum(A::AbstractArray{<:Real}) = valid_minimum(isfinite, A)

"""
    finite_maximum(A) -> vmax

yields the maximum finite value in array `A`.  The result is never a NaN but
may be `typemin(eltype(A))` if there are no finite values in `A`.

"""
finite_maximum(A::AbstractArray{<:Real}) = valid_maximum(isfinite, A)

"""
    valid_extrema(pred, A) -> (vmin, vmax)

yields the minimum and maximum valid values in array `A`.  Valid values are
those for which predicate `pred` yields `true`.  The result is such that `vmin
≤ vmax` (both values being valid) unless there are no valid values in `A` in
which case `vmin > vmax`.  The predicate function is assumed to take care of
NaN's.

"""
function valid_extrema(pred, A::AbstractArray{T}) where {T}
    vmin = typemax(T)
    vmax = typemin(T)
    @inbounds @simd for i in eachindex(A)
        val = A[i]
        vmin = ifelse(pred(val)&(val < vmin), val, vmin)
        vmax = ifelse(pred(val)&(val > vmax), val, vmax)
    end
    return (vmin, vmax)
end
valid_extrema(::typeof(isfinite), A::AbstractRange{<:Real}) = extrema(A)

"""
    valid_minimum(A) -> vmin

yields the minimum valid value in array `A`.  Valid values are those for which
predicate `pred` yields `true`.  The result is a valid value but may be
`typemax(eltype(A))` if there are no valid values in `A`.  The predicate
function is assumed to take care of NaN's.

"""
function valid_minimum(pred, A::AbstractArray{T}) where {T}
    vmin = typemax(T)
    @inbounds @simd for i in eachindex(A)
        val = A[i]
        vmin = ifelse(pred(val)&(val < vmin), val, vmin)
    end
    return vmin
end
valid_minimum(::typeof(isfinite), A::AbstractRange{<:Real}) = minimum(A)

"""
    valid_maximum(A) -> vmax

yields the maximum valid value in array `A`.  Valid values are those for which
predicate `pred` yields `true`.  The result is a valid value but may be
`typemin(eltype(A))` if there are no valid values in `A`.  The predicate
function is assumed to take care of NaN's.

"""
function valid_maximum(pred, A::AbstractArray{T}) where {T}
    vmax = typemin(T)
    @inbounds @simd for i in eachindex(A)
        val = A[i]
        vmax = ifelse(pred(val)&(val > vmax), val, vmax)
    end
    return vmax
end
valid_maximum(::typeof(isfinite), A::AbstractRange{<:Real}) = maximum(A)

end # module
