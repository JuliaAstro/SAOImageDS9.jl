#
# SAOImageDS9.jl --
#
# Implement communication with SAOImage/DS9 (http://ds9.si.edu) via the XPA
# protocol.
#
#------------------------------------------------------------------------------
#
# This file is part of SAOImageDS9.jl released under the MIT "expat" license.
# Copyright (c) 2016-2025, Éric Thiébaut (https://github.com/emmt).
#

module SAOImageDS9

export ds9accesspoint
export ds9connect
export ds9cursor
export ds9disconnect
export ds9draw
export ds9get
export ds9getregions
export ds9launch
export ds9message
export ds9quit
export ds9set
export ds9wcs

export DS9
const DS9 = SAOImageDS9

using XPA
using XPA: AccessPoint, Shape, TupleOf, connection, join_arguments
using XPA: preserve_state, restore_state

using TwoDimensional

import REPL
using REPL.TerminalMenus

using Base: ENV
using Base.Iterators: Pairs

# FITS pixel types.
const PIXEL_TYPES = (UInt8, Int16, Int32, Int64, Float32, Float64)
const PixelTypes = Union{PIXEL_TYPES...,}

#---------------------------------------------------------------------------- ACCESS-POINT -

# Private global variable storing the default access-point to SAOImage/DS9.
const _DEFAULT_APT = Ref{AccessPoint}()

# `default_apt()` yields the default access-point and attempts to automatically find one
# if the default one is closed.
function default_apt()
    apt = ds9accesspoint()
    return isopen(apt) ? apt : ds9connect()
end

"""
    ds9accesspoint() -> apt

Yield the current default XPA access-point to SAOImage/DS9.

# See also

[`ds9connect`](@ref) and  [`ds9disconnect`](@ref).

"""
ds9accesspoint() = _DEFAULT_APT[]

"""
    ds9disconnect()

Forget the default XPA access-point to SAOImage/DS9.

# See also

[`ds9accesspoint`](@ref) and [`ds9connect`](@ref).

"""
ds9disconnect() = ds9connect(AccessPoint())

"""
    ds9connect(apt::XPA.AccessPoint) -> apt
    ds9connect(addr::AbstractString) -> apt
    ds9connect(; kwds...) -> apt
    ds9connect(f; kwds...) -> apt

Set the default XPA access-point to SAOImage/DS9 and return it. The access-point may be
fully specified (1st example), specified by its address (2nd example), or found among a
list of running SAOImage/DS9 (3rd and 4th examples) by calling `XPA.find` with filter
function `f` and keywords `kwds...`. If not specified (3rd example), the default filter
function is:

   apt -> apt.class == "DS9" && apt.user == ENV["USER"]

When calling `XPA.find`, the default value of the `select` keyword is `:interact` if Julia
is running an interactive session.

# See also

[`ds9accesspoint`](@ref) and [`ds9disconnect`](@ref).

"""
function ds9connect(apt::XPA.AccessPoint)
    _DEFAULT_APT[] = apt
    return apt
end

function ds9connect(addr::AbstractString)
    return ds9connect(AccessPoint(address=addr))
end

function ds9connect(; kwds...)
    return ds9connect(; kwds...) do apt
        global ENV
        apt.class == "DS9" && apt.user == ENV["USER"]
    end
end

function ds9connect(f; select = isinteractive() ? :interact : :throw, kwds...)
    return ds9connect(XPA.find(f; select=select, kwds...))
end

#--------------------------------------------------------------------------- LAUNCH / QUIT -

"""
    ds9launch([name]; method="local", exe="ds9", timeout=30, quiet=false)

Launch the SAOImage/DS9 application and connect to it. Optional argument `name` is the
name (and title) of the SAOImage/DS9 server to identity it. By default, the name is the
given by the current PID. The default access-point is set to that of the new server.

# Keywords

- `method` is the type of connection to use. The default method is `ENV["XPA_METHOD"]` if
  this environment variable is set and `"local"` otherwise.

- `exe` is the path to SAOImage/DS9 executable.

- `timeout` is the maximum number of seconds to wait for connecting.

- `quiet` specifies whether to print information and warning messages.

# See also

[`ds9connect`](@ref) and [`ds9quit`](@ref).

"""
function ds9launch(name::AbstractString = string(getpid());
                   method::Union{Symbol,AbstractString} = get(ENV, "XPA_METHOD", "local"),
                   exe="ds9",
                   quiet::Bool=false, timeout::Real=30)
    global ENV
    preserve_state(ENV, "XPA_METHOD") do
        delete!(ENV, "XPA_METHOD")
        run(detach(`$exe -xpa $method -title $name`); wait=false)
    end
    if !quiet
        printstyled("[ Info:"; color=Base.default_color_info, bold=true)
        print(" Opening DS9 with name $(repr(name))")
    end
    maxtime = time() + timeout
    while time() ≤ maxtime
        quiet || print(".")
        sleep(0.4)
        apt = XPA.find(; method=method, select=:throw) do apt
            apt.class == "DS9" && apt.name == name
        end
        if !isnothing(apt)
            ds9connect(apt)
            quiet || println(" done")
            return nothing
        end
    end
    quiet || println(" failed")
    @warn "Timeout establishing an XPA connection."
    return nothing
end

"""
    ds9quit()
    ds9quit(apt::XPA.Accesspoint)
    ds9quit(addr::AbstractString)

Require SAOImage/DS9 application to quit. With no argument, the default SAOImage/DS9
application is closed. Otherwise, a specific SAOImage/DS9 application may be targeted by
specifying its access-point `apt` or the address `addr` of its access-point.

See also [`ds9accesspoint`](@ref) and  [`ds9disconnect`](@ref).

"""
ds9quit(addr::AbstractString) = ds9quit(AccessPoint(address = addr))

function ds9quit(apt::AccessPoint = default_apt())
    if isopen(apt)
        ds9set(apt, "quit")
        if apt.address == default_apt().address
            ds9disconnect()
        end
    end
    return nothing
end

#------------------------------------------------------------------------------- GET / SET -

"""
    ds9get([apt,] [T, [dims,]] args...)

Send a "get" request to a SAOImage/DS9 server.

The request is made of arguments `args...` converted into strings and concatenated with
separating spaces.

The returned value depends on the optional arguments `T` and `dims`:

FIXME: * If neither `T` nor `dims` are specified, the output is converted using an heuristic method
FIXME:   to suitable scalar or vector.

* If only `T` is specified, it can be:

  - `String` to return the answer as a single string;

  - `Vector{String}}` or `Tuple{Vararg{String}}` to return the answer split in words as a
    vector or as a tuple of strings;

  - `T` where `T<:Real` to return a value of type `T` obtained by parsing the textual
    answer.

  - `Tuple{Vararg{T}}` where `T<:Real` to return a value of type `T` obtained by parsing the
    textual answer;

  - `Vector{T}` where `T` is not `String` to return the binary contents of the answer as a
    vector of type `T`;

* If both `T` and `dims` are specified, `T` can be an array type like `Array{S}` or
  `Array{S,N}` and `dims` a list of `N` dimensions to retrieve the binary contents of the
  answer as an array of type `Array{S,N}`.

# See also

[`ds9connect`](@ref) and [`ds9set`](@ref).

"""
ds9get(args...; kwds...) = ds9get(default_apt(), args...; kwds...)
ds9get(apt::AccessPoint, args...; kwds...) = ds9get(apt, XPA.join_arguments(args); kwds...)

# Yields result as a vector of numerical values extracted from the binary contents of the
# reply.
ds9get(apt::AccessPoint, ::Type{Vector{T}}, args...; kwds...) where {T} =
    XPA.get(Vector{T}, apt, join_arguments(args); kwds...)

# Idem with given number of elements.
ds9get(apt::AccessPoint, ::Type{Vector{T}}, dim::Integer, args...; kwds...) where {T} =
    XPA.get(Vector{T}, (dim,), apt, join_arguments(args); kwds...)

# Yields result as an array of numerical values with given dimensions and extracted from the
# binary contents of the reply.
ds9get(apt::AccessPoint, ::Type{Array{T,N}}, dims::NTuple{N,Integer}, args...; kwds...) where {T,N} =
    XPA.get(Array{T,N}, dims, apt, join_arguments(args); kwds...)

# Idem but number of dimensions not specified.
ds9get(apt::AccessPoint, ::Type{Array{T}}, dims::NTuple{N,Integer}, args...; kwds...) where {T,N} =
    ds9get(apt, Array{T,N}, dims, args...; kwds...)

# Yields result as a single string.
ds9get(apt::AccessPoint, ::Type{String}, args...; kwds...) =
    XPA.get(String, apt, join_arguments(args); kwds...)

# Yields result as a vector of strings split out of the textual contents of the reply.
ds9get(apt::AccessPoint, ::Type{Vector{String}}, args...; delim = isspace, keepempty::Bool=false, kwds...) =
    split(chomp(ds9get(apt, String, args...; kwds...)), delim; keepempty=keepempty)

# Yields result as a tuple of strings split out of the textual contents of the reply.
ds9get(apt::AccessPoint, ::Type{TupleOf{String}}, args...; kwds...) =
    Tuple(ds9get(apt, Vector{String}, args...; kwds...))

# Yields result as a numerical value parsed from the textual contents of the reply.
ds9get(apt::AccessPoint, ::Type{T}, args...; kwds...) where {T<:Real} =
    _parse(T, ds9get(apt, String, args...; kwds...))::T

# Yields result as a tuple of numerical values parsed from the textual contents
# of the reply.
ds9get(apt::AccessPoint, ::Type{TupleOf{T}}, args...; kwds...) where {T<:Real} =
    _parse(TupleOf{T}, ds9get(apt, String, args...; kwds...))

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

function _parse(::Type{TupleOf{T}}, str::AbstractString) where {T<:Real}
    return Tuple(map(s -> _parse(T, s), split(str; keepempty=false)))
end

"""
    ds9get([accesspoint,] Array; endian=:native, kwds...)

Returns the contents of current SAOImage/DS9 frame as an array.

The keyword `endian` can be used to specify the byte order of the received values (see
[`SAOImageDS9.byte_order`](@ref)). This method returns `nothing` if the frame is empty.

"""
function ds9get(apt::AccessPoint, ::Type{Array};
                endian::Union{Symbol,AbstractString}=:native, kwds...)
    T = bitpix_to_type(ds9get(apt, Int, "fits bitpix"; kwds...))
    if T === Nothing
        return nothing
    end
    dims = ds9get(apt, TupleOf{Int}, "fits size"; kwds...)
    return ds9get(apt, Array{T}, dims, "array", byte_order(endian); kwds...)
end

"""
    ds9get([accesspoint,] VersionNumber)

Retrieve the version of the SAOImage/DS9 program.
"""
function ds9get(apt::AccessPoint, ::Type{VersionNumber}; kwds...)
    str = ds9get(apt, String, "version"; kwds...)
    return VersionNumber(split(str, " ")[end])
end

"""
    ds9set([apt,] args...; data=nothing, throwerrors=true, quiet=false, kwds...)

send a command and/or data to the SAOImage/DS9 server. Optional `apt` is to specify
another access-point to a SAOImage/DS9 server than the default one. The sent command is
made of `args...` converted into a single string with elements of `args...`
separated by a single space.

# Keywords

* `data` is to specify the data to send.

* `throwerrors` is to specify whether to throw an exception in case of error(s) in the XPA
  reply.

* `quiet` is to specify whether to not warn about any errors in the XPA reply.

* `kwds...` are other keywords for `XPA.set`.

See also: [`ds9connect`](@ref) and [`ds9get`](@ref).

"""
ds9set(args...; kwds...) = ds9set(default_apt(), args...; kwds...)

ds9set(apt::AccessPoint, args...; kwds...) = ds9set(apt, join_arguments(args); kwds...)

function ds9set(apt::AccessPoint, cmd::AbstractString;
                throwerrors::Bool=true, quiet::Bool=false, kwds...)
    r = XPA.set(apt.address, cmd; kwds...)
    if throwerrors || !quiet
        if length(r) == 0
            quiet || @warn "No replies for command `$cmd`"
        else
            msg1 = "" # first error message if any
            for a in r
                if a.has_error
                    msg = a.message
                    quiet || @warn msg
                    if isempty(msg1)
                        msg1 = msg
                    end
                end
            end
            if throwerrors && !isempty(msg1)
                error(msg1)
            end
        end
    end
    return nothing
end

"""
    ds9set([apt,] arr; mask=false, new=false, endian=:native, kwds...)

set the contents of an SAOImage/DS9 frame to be array `arr`. Optional `apt` is to specify
another access-point to a SAOImage/DS9 server than the default one.

# Keywords

* `mask` is true to control the DS9 mask parameters.

* `frame` specifies a frame number or is `:new` to create a new frame.

* `endian` specifies the byte order of `arr` (see [`SAOImageDS9.byte_order`](@ref)).

* `kwds...` are other keywords for `ds9set`.

"""
function ds9set(apt::AccessPoint, arr::AbstractArray{T,N};
                endian::Symbol=:native, mask::Bool=false,
                frame=nothing, kwds...) where {T<:PixelTypes,N}
    args = String["array"]
    if frame !== nothing
        mask && throw(ArgumentError("keyword `mask` must be false if keyword `frame` is something"))
        if frame === :new
            push!(args, "new")
        elseif frame isa Integer
            ds9set(apt, "frame", frame)
        else
            throw(ArgumentError("keyword `frame` must be `nothing`, `:new`, or an integer"))
        end
    end
    data = to_pixels(arr)
    push!(args, array_descriptor(data; endian=endian));
    return ds9set(apt, join(args, ' '); data=data, kwds...)
end

to_pixels(A::DenseArray{T}) where {T<:PixelTypes} = A
to_pixels(A::AbstractArray{T}) where {T<:PixelTypes} = convert(Array{T}, A)::DenseArray{T}

# Convert other pixel types.
for (T, S) in (Int8   => Int16,
               UInt16 => Float32,
               Real   => Float64,)
    @eval to_pixels(A::AbstractArray{$T}) = convert(Array{$S}, A)::DenseArray{$S}
end

function array_descriptor(arr::AbstractArray{T,N}; endian::Symbol=:native) where {T,N}
    2 ≤ N ≤ 3  || throw(ArgumentError("only 2- or 3-dimensional arrays are supported"))
    arr isa DenseArray || throw(ArgumentError("data must be a dense array"))
    bp = bitpix_of(T)
    iszero(bp) &&  throw(ArgumentError("unsupported pixel type `$T`"))
    if N == 2
        return string("[xdim=",size(arr,1),",ydim=",size(arr,2),
                      ",bitpix=",bp,",endian=",endian,"]")
    else
        return string("[xdim=",size(arr,1),",ydim=",size(arr,2),",zdim=",size(arr,3),
                      ",bitpix=",bp,",endian=",endian,"]")
    end
end

"""
    bitpix_of(x) -> bp

yields FITS bits-per-pixel (BITPIX) value for `x` which can be an array or a type. A value
of 0 is returned if `x` is not of a supported type.

See also [`SAOImageDS9.bitpix_to_type`](@ref).

"""
bitpix_of(::AbstractArray{T}) where {T} = bitpix_of(T)
for T in PIXEL_TYPES
    bp = (T <: Integer ? 8 : -8)*sizeof(T)
    @eval bitpix_of(::Type{$T}) = $bp
    @eval bitpix_of(::$T) = $bp # FIXME
end
bitpix_of(::Any) = 0

"""
    bitpix_to_type(bp) -> T

Return the Julia type corresponding to FITS bits-per-pixel (BITPIX) value
`bp`.

yields Julia type corresponding to FITS bits-per-pixel (BITPIX) value `bp`. The type
`Nothing` is returned if `bp` is unknown.

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
    byte_order(endian)

yields the byte order for retrieving the elements of a SAOImage/DS9 array. Argument can be
one of the strings (or the equivalent symbol): `"big"` for most significant byte first,
`"little"` for least significant byte first or `"native"` to yield the byte order of the
machine.

See also [`ds9get`](@ref), [`ds9set`](@ref).

"""
function byte_order(endian::Symbol)
    if endian == :native
        if ENDIAN_BOM == 0x01020304
            return "big"
        elseif ENDIAN_BOM == 0x04030201
            return "little"
        else
            error("unknown byte order")
        end
    elseif endian == :big
        return "big"
    elseif endian == :little
        return "little"
    else
        error("invalid byte order")
    end
end
byte_order(endian::AbstractString) = byte_order(Symbol(endian))

#------------------------------------------------------------------------------
# DRAWING

"""
    ds9draw([apt,] args...; kwds...)

Draws something in SAOImage/DS9 application.

The specific operation depends on the type of the arguments.

"""
ds9draw(args...; kwds...) = ds9draw(default_apt(), args...; kwds...)
ds9draw(apt::AccessPoint, ::Tuple{}; kwds...) = nothing
ds9draw(apt::AccessPoint, ::T; kwds...) where {T} = error("unexpected type of argument(s): $T")

"""
    ds9draw([apt,] img::AbstractMatrix; kwds...)

Displays image `img` (a 2-dimensional Julia array) in SAOImage/DS9.

# Keywords
- `frame`: to select a given frame number, or `:new` to draw image in a new frame;
- `cmap`: uses the named colormap;
- `zoom`: fixes the zoom factor;
- `min` & `max`: fix the scale limits.
"""
function ds9draw(apt::AccessPoint, img::AbstractMatrix;
                 min::Union{Real,Nothing}=nothing,
                 max::Union{Real,Nothing}=nothing,
                 cmap=nothing, zoom=nothing, kwds...)
    zoom === nothing || ds9set(apt, "zoom to", zoom)
    ds9set(apt, img; kwds...)
    if min !== nothing || max !== nothing
        ds9set(apt, "scale limits", limits(img, min, max)...)
    end
    cmap === nothing || ds9set(apt, "cmap", cmap)
    return nothing
end

# For multiple points/circles/... we just send a command to SAOImage/DS9 for each item to
# draw. Packing multiple commands (separated by semi-columns) does not really speed-up
# things and is more complicated because there is a limit to the total length of an XPA
# command (given by `XPA.SZ_LINE`).

"""
    ds9draw([accesspoint,] pnt; kwds...)

Draw `pnt` as point(s) in SAOImage/DS9.

`pnt` can be a `Point`, an array, or a tuple of `Point`'s.
"""
ds9draw(apt::AccessPoint, A::Point; kwds...) = _draw(apt, _region(Val(:point), kwds), A)
function ds9draw(apt::AccessPoint, A::Union{Tuple{Vararg{Point}},
    AbstractArray{<:Point}}; kwds...)
    cmd = _region(Val(:point), kwds)
    for i in eachindex(A)
        _draw(apt::AccessPoint, cmd, A[i])
    end
end

"""
    ds9draw([accesspoint,] box; kwds...)

Draws `box` as rectangle(s) in SAOImage/DS9.

box` can be a `BoundingBox`, an array, or a tuple of `BoundingBox`'es.
"""
ds9draw(apt::AccessPoint, A::BoundingBox; kwds...) = _draw(apt, _region(Val(:polygon), kwds), A)
function ds9draw(apt::AccessPoint, A::Union{Tuple{Vararg{BoundingBox}},
    AbstractArray{<:BoundingBox}}; kwds...)
    cmd = _region(Val(:polygon), kwds)
    for i in eachindex(A)
        _draw(apt, cmd, A[i])
    end
end

function _draw(apt::AccessPoint, cmd::NTuple{2,AbstractString}, A::Point)
    ds9set(apt, cmd[1], A.x, A.y, cmd[2])
    nothing
end

function _draw(apt::AccessPoint, cmd::NTuple{2,AbstractString}, A::BoundingBox)
    x0, x1, y0, y1 = Tuple(A)
    ds9set(apt, cmd[1], x0, y0, x1, y0, x1, y1, x0, y1, x0, y0, cmd[2])
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
    cmd = "region command { $id"
    @eval _region(::$V, kwds::Pairs) = ($cmd, _set_options(kwds))
end

"""
    ds9message([apt,] text; cancel=false)

Display a dialog with a message given by `text`.

If `cancel=true`, a *Cancel* button is added to the dialog: in that case, the return value
is `true` or `false` depending on the button pressed by the user.

"""
ds9message(msg::AbstractString; kwds...) =  ds9message(default_apt(), msg; kwds...)
function ds9message(apt::AccessPoint, msg::AbstractString; cancel::Bool = false)
    btn = (cancel ? "okcancel" : "ok")
    cmd = "analysis message $btn {$msg}"
    return tryparse(Int, XPA.get(String, apt, cmd)) == 1
end

"""
    ds9cursor([apt]; text="", cancel=false, coords=:image, event=:button)

Returns the position of the mouse cursor in SAOImage/DS9 interactively chosen by the user.
The function returns the tuple `(key, x, y)` or `(key, value)`, where `key` is the key
pressed, `(x, y)` are the coordinates of the point selected, and `value` the corresponding
value.

# Keywords

- `text` specifies a message to be displayed in a dialog first.

- `cancel` specifies whether the dialog message will let the user cancel the operation (in
  this case this function returns `nothing`).

- `event` is the type of event to capture the cursor position, one of `:button`, `:key`, or
  `:any`.

- `coords` is the type of coordinates to return, one of `:data`, `:image`, `:physical`,
  `:fk5`, or `galactic` (as a string or as a symbol). If set to `data`, this function
  returns the value of the pixel, instead of its coordinates.

"""
function ds9cursor(apt::Union{AbstractString,AccessPoint}=default_apt();
                   text::AbstractString="", cancel::Bool=false,
                   coords::Symbol=:image, event::Symbol=:button)
    event ∈ (:button, :key, :any) || throw(ArgumentError(
        "unknown event type `$(repr(event))`, must be one of `:button`, `:key`, or `:any`"))
    if isempty(text)
        XPA.set(apt, "raise")
    else
        ds9message(apt, text; cancel=cancel) || return nothing
    end
    cmd = string("iexam ", event, (coords === :data ? " " : " coordinate "), coords)
    words = split(XPA.get(String, apt, cmd))
    if event === :button
        return ("<1>", parse.(Float64, words)...)
    else
        return (words[1], parse.(Float64, @view words[2:end])...)
    end
end

function cube(; apt=default_apt())
    get_and_parse(Int, apt, "cube")
end
function cube(z::Integer; apt=default_apt())
    XPA.set(apt, "cube $z")
end

function cube_interval(; apt=default_apt())
    get_and_parse(Float64, apt, "cube interval")
end
function cube_interval(dt::Real; apt=default_apt())
    XPA.set(apt, "cube interval $dt")
end

#------------------------------------------------------------------------------
# LIMITS

"""
    SAOImageDS9.limits(A, cmin=nothing, cmax=nothing) -> (lo, hi)

yields the clipping limits of values in array `A`. The result is a 2-tuple of double
precision floats `(lo,hi)`. If `cmin` is `nothing`, `lo` is the minimal finite value found
in `A` and converted to `Cdouble`; otherwise `lo = Cdouble(cmin)`. If `cmax` is `nothing`,
`hi` is the maximal finite value found in `A` and converted to `Cdouble`; otherwise `hi =
Cdouble(cmax)`.

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


"""
    ds9wcs([apt]; useheader=true)

Return the cards of the FITS header defining the WCS transformation of current
SAOImage/DS9 frame.

# Keywords

- `useheader` specifies whether to extract WCS transformation from the FITS header.
  Otherwise, the WCS transformation is extracted from the result of the `"wcs save"`
  command.

"""
function ds9wcs(apt::Union{AbstractString,AccessPoint} = default_apt();
                useheader::Bool = true)
    wcskeys = r"^(WCSAXES|C(RPIX|RVAL|TYPE|DELT|UNIT)[1-9] |(PC|CD|PV)[1-9]_[1-9]  |RADESYS|LATPOLE|LONPOLE) ="
    if useheader
        header = XPA.get(String, apt, "fits header")
    else
        path = tempname()
        XPA.set(apt, "wcs save", path)
        header = open(path) do f
            read(f, String)
        end
        rm(path, force=true)
    end
    return filter(startswith(wcskeys), split(header, "\n"))
end

"""
    ds9getregions([access_point,] name=""; coords=:image, selected=false)

Return the regions defined in the DS9 window.

The optional argument `name` is the name of the group of regions to extract.
If `name` is an empty string, all regions are extracted.

# Keyword Arguments
- `ident`: the identifier of the DS9 window.
- `coords`: the type of coordinates to return: can be `:image`, `:physical`,
  `:fk5`, `:galactic`

The return value is a vector of 3-tuples `(shape, coordinates, properties)`,
where `shape` is a symbol indicating shape of the region, `coordinates` is an
array of coordinates, and `properties` is a dictionary with the properties of
the region. Note that the code parses as much as possible the properties:
therefore, the returned dictionary can include a variety of different value
types, depending on the keyword. The followin rules applies

- the global properties are always _merged_ to the more specific region
  properties;
- properties with boolean meaning, such as `:select`, `:edit`, or `:rotate`
  are suitably converted to `true` or `false`;
- properties enclosed within single quotes ('...'), double quotes ("..."), or
  braces ({...}) are returned as strings with the boundary markers removed;
- since a region can contain multiple tag specifications, the `:tag` property
  is always returned as an array of strings;
- properties consisting of multiple elements, such as `:dash`, `:line`, and
  `:point` are returned as tuples.
"""
function ds9getregions(apt::AccessPoint, name::String; coords=:image, selected=false)
    function parsevalue(prop, value)
        r = tryparse(Int, value)
        if r === nothing
            r = tryparse(Float64, value)
            if r === nothing
                r = value
            end
        end
        if prop ∈ [:delete, :highlite, :edit, :move, :rotate, :include, :select, :fixed,
            :source, :dash, :fill]
            r = (r == 1)
        end
        r
    end
    function parseproperties!(props, line)
        regexp = r"\b([_A-Za-z]\w*)\b(?:=([0-9 ]*[0-9]+|\b[\w.]+\b(?:\s+[0-9]+\b)?|{[^}]*}|\"[^\"]*\"|\'[^\']*\'))?"
        for m ∈ eachmatch(regexp, line)
            prop = Symbol(m.captures[1])
            value = m.captures[2]
            if value === nothing
                if prop == :background
                    props[:source] = false
                else
                    props[prop] = true
                end
            elseif prop == :dashlist
                props[prop] = tuple(tryparse.(Int, split(value))...)
            elseif prop == :line
                props[prop] = tuple(parsevalue.(Ref(prop), split(value))...)
            elseif length(value) > 1 && ((value[1] == value[end] == '"') ||
                    (value[1] == value[end] == '\'') || (value[1] == '{' && value[end] == '}'))
                if prop == :tag
                    if haskey(props, :tag)
                        push!(props[:tag], value[2:end-1])
                    else
                        props[prop] = String[value[2:end-1]]
                    end
                else
                    props[prop] = value[2:end-1]
                end
            else
                props[prop] = parsevalue(prop, value)
            end
        end
        props
    end

    # Query DS9 for the regions and the selections
    group = (name != "") ? "-group $name" : ""
    sel = selected ? "selected" : ""
    reply = XPA.get(apt, "regions $sel -format ds9 $group -system $coords")
    regs = split(XPA.get_data(String, reply), "\n")
    # Extract the global settings
    global_lines = filter(line -> startswith(line, "global "), regs)
    global_props = Dict{Symbol,Any}()
    for line in global_lines
        parseproperties!(global_props, line[8:end])
    end
    regions = Tuple{Symbol,Vector{Float64},Dict{Symbol,Any}}[]
    for line ∈ regs
        m = match(r"^\s*([-+]?)(circle|ellipse|box|polygon|point|line|vector|segment|text|ruler|compass|projection|annulus|panda|epanda|bpanda|composite)\(([^)]+)\)\s*(#.*)?$", line)
        if m !== nothing
            include = m.captures[1] != "-"
            shape = Symbol(m.captures[2])
            coords = parse.(Float64, split(m.captures[3], ","))
            comment = isnothing(m.captures[4]) ? "" : m.captures[4][2:end]
            local_props = copy(global_props)
            local_props[:include] = include
            parseproperties!(local_props, comment)
            push!(regions, (shape, coords, local_props))
        end
    end
    return regions
end
@inline ds9getregions(name::String=""; kwds...) = ds9getregions(default_apt(), name; kwds...)

function __init__()
    ds9disconnect()
end

end # module
