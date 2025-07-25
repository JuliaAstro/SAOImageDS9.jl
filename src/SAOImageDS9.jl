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
export ds9iexam
export ds9launch
export ds9message
export ds9quit
export ds9set
export ds9wcs

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

const VectorLike{T} = isdefined(Base, :Memory) ?
    Union{Memory{T},AbstractVector{T},Tuple{Vararg{T}}} :
    Union{AbstractVector{T},Tuple{Vararg{T}}}

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

#---------------------------------------------------------------------------------- DS9GET -

"""
    ds9get([apt,] args...; kwds...) -> r::AbstractString
    ds9get(T::Type, [apt,] args...; kwds...) -> r::T

Send a single XPA *get* command to SAOImage/DS9.

The command is made of arguments `args...` converted into strings and concatenated with
separating spaces.

Optional argument `T` is to specify the type of value to extract from the answer of the
command:

- If `T` is `eltype(XPA.Reply)`, `r` is the un-processed answer of the command. The caller
  may use properties `r.data`, `r.message`, `r.has_message`, `r.has_error` etc. to deal
  with it. In all other cases, the answer is interpreted as an ASCII string, the so-called
  *textual answer*.

- If `T` is unspecified, the *textual answer* is returned without its trailing newline
  (`'\\n'` character).

- If `T` is `String`, the *textual answer* is returned (without discarding any
  characters).

- If `T` is a *scalar type*, a value of this type is parsed in the *textual answer* and
  returned.

- If `T` is a *tuple or vector type*, the *textual answer* is split into words which are
  scanned for 0, 1, or more values according to the type(s) of the entries of `T`.

Optional argument `apt` is to specify another access-point to a SAOImage/DS9 server than
the default one.

If `T` and `apt` are both specified, their order is irrelevant.

For example:

```julia-repl
julia> ds9get(Tuple{Float64,Float64,Float64}, "iexam {\$x \$y \$value}")
(693.0, 627.0, 64.0)

julia> ds9get(Tuple{Int,Int}, "fits size")
(1024, 1024)

julia> ds9get(Bool, "frame has amplifier")
false

julia> ds9get(Tuple{String,VersionNumber}, "version")
("ds9-8.7b1", v"8.7.0-b1")

```

# See also

[`ds9connect`](@ref) and [`ds9set`](@ref).

The page https://ds9.si.edu/doc/ref/xpa.html for a list of XPA commands implemented by
SAOImage/DS9. This documentation is also available via the menu *Help* > *Reference
Manual* > *XPA Access Points* of SAOImage/DS9.

"""
function ds9get(args...; kwds...)
    return ds9get(default_apt(), args...; kwds...)
end

function ds9get(apt::AccessPoint, args...; kwds...)
    return chomp(ds9get(String, apt, args...; kwds...))
end

function ds9get(::Type{T}, args...; kwds...) where {T}
    return ds9get(T, default_apt(), args...; kwds...)
end

function ds9get(apt::AccessPoint, ::Type{T}, args...; kwds...) where {T}
    return ds9get(T, apt, args...; kwds...)
end

function ds9get(::Type{T}, apt::AccessPoint, args...; kwds...) where {T}
    return scan(T, ds9get(String, apt, args...; kwds...))
end

function ds9get(::Type{String}, apt::AccessPoint, args...; kwds...)
    r = ds9get(eltype(XPA.Reply), apt, args...; kwds...)
    return r.data(String; take=true)
end

function ds9get(::Type{eltype(XPA.Reply)}, apt::AccessPoint, args...;
                throwerrors::Bool=true, kwds...)
    return XPA.get(apt, args...; throwerrors=throwerrors, nmax=1, kwds...)[]
end

"""
    ds9get(A::Type{<:Array} [, apt]; kwds...) -> arr::A

Returns the contents of current SAOImage/DS9 frame as an array.

Result type `A` may be `Array`, `Array{T}`, `Array{T,N}`, etc. depending on which type
parameters are known (or imposed). Having a more qualified array type `A` reduces the
uncertainty of the result.

"""
function ds9get(::Type{A}, apt::AccessPoint=default_apt(); kwds...) where {A<:Array}
    # Get image size (as un-parsed words) to check the number of dimensions `N` (if
    # specified in result type) and call auxiliary function to dispatch on `N`.
    dims = split(ds9get(String, apt, "fits size"; kwds...))
    N = length(dims)
    !has_ndims(A) || ndims(A) == N || throw(DimensionMismatch(
        "$N-dimensional image incompatible with $(ndims(A))-dimensional array type"))
    return convert(A, get_pixels(Array{Any,N}, dims, apt; kwds...))
end

function get_pixels(::Type{Array{T,N}}, dims::Vector{<:AbstractString},
                    apt::AccessPoint; kwds...) where {T,N}
    if T === Any
        # Only number of dimensions `N` is known: determine pixel type `T` and dispatch on
        # `T` and `N`.
        Tp = bitpix_to_type(ds9get(Int, apt, "fits bitpix"; kwds...))
        return get_pixels(Array{Tp,N}, dims, apt; kwds...)
    else
        # Element type and number of dimensions are known, the result is type-stable.
        r = ds9get(eltype(XPA.Reply), apt, "array native"; kwds...)
        return r.data(Array{T,N}, scan(Dims{N}, dims); take=true)
    end
end

has_ndims(::Type{<:AbstractArray}) = false
has_ndims(::Type{<:AbstractArray{<:Any,N}}) where {N} = true

"""
    ds9get(VersionNumber [, apt]; kwds...)

Retrieve the version of SAOImage/DS9.

"""
function ds9get(::Type{VersionNumber}, apt::AccessPoint = default_apt(); kwds...)
    str = ds9get(String, apt, "version"; kwds...)
    return VersionNumber(last(split(str)))
end

#---------------------------------------------------------------------------------- DS9SET -

"""
    ds9set([apt,] args...; data=nothing, throwerrors=true, quiet=false, kwds...)

Send a single XPA *set* command to SAOImage/DS9.

The command is made of arguments `args...` converted into strings and concatenated with
separating spaces.

Optional argument `apt` is to specify another access-point to a SAOImage/DS9 server than
the default one.

# Keywords

* `data` is to specify the data to send.

* `throwerrors` is to specify whether to throw an exception in case of error(s) in the XPA
  reply.

* `quiet` is to specify whether to not warn about any errors in the XPA reply.

* `kwds...` are other keywords for `XPA.set`.

# See also

[`ds9connect`](@ref) and [`ds9get`](@ref).

The page https://ds9.si.edu/doc/ref/xpa.html for a list of XPA commands implemented by
SAOImage/DS9. This documentation is also available via the menu *Help* > *Reference
Manual* > *XPA Access Points* of SAOImage/DS9.

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
    ds9set([apt,] arr; mask=false, frame=nothing, endian=:native, kwds...)

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
                frame::Union{Nothing,Integer,Symbol}=nothing, kwds...) where {T<:PixelTypes,N}
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
    bitpix_to_type(bpp) -> T

Return the Julia type corresponding to FITS BITPIX (bits-per-pixel) value `bpp`.

# See also

[`SAOImageDS9.bitpix_of`](@ref).

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

# See also

[`ds9get`](@ref), [`ds9set`](@ref).

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

#------------------------------------------------------------------------------------ SCAN -

"""
    SAOImageDS9.scan(T, str) -> x::T

Scan string(s) `str` for value of type `T`.

If `T` is not a tuple nor an array type and `str` is a scalar string, `scan(T, str)` is
like `convert(T, str)` if `T <: Union{AbstractString,Symbol}` and like `parse(T, str)`
otherwise. For example:

```julia
julia> SAOImageDS9.scan(String, "Hello world!")
"Hello world!"

julia> SAOImageDS9.scan(Symbol, "Hello world!")
Symbol("Hello world!")

julia> SAOImageDS9.scan(Int, " 33  ")
33
```

If `T` is a tuple or array type, `str` must be an array or a tuple of strings with same
number of dimensions as `T` (one if `T` is a tuple type). However, if `str` is a single
string and `T` is a tuple or vector type, then `str` is split in tokens by `split(str)`
before being scanned. For example:

```julia
julia> SAOImageDS9.scan(Tuple{Symbol,String}, "Hello world!")
(:Hello, "world!")

julia> SAOImageDS9.scan(Vector{Int}, " 12 345 6789\n")
3-element Vector{Int64}:
   12
  345
 6789

julia> SAOImageDS9.scan(Tuple{Int,Int,Float64}, " 12 345 6789\n")
(12, 345, 6789.0)

julia> SAOImageDS9.scan(Tuple{Int,Int,Float64}, ["12", "345", "6789"])
(12, 345, 6789.0)
```

"""
scan(::Type{T}, str::AbstractString) where {T<:Tuple} = scan(T, split(str))
scan(::Type{T}, str::AbstractString) where {T<:AbstractVector} = scan(T, split(str))

@generated function scan(::Type{T}, tokens::VectorLike{<:AbstractString}) where {T<:Tuple}
    code = Expr[]
    types = fieldtypes(T)
    n = length(types)
    push!(code, :(length(tokens) == $n || throw(DimensionMismatch(
        string("expecting ", $n, " token(s), got ", length(tokens))))))
    result = Expr(:tuple)
    if n ≥ 1
        push!(code, :(off = firstindex(tokens) - 1))
        for (i, t) in enumerate(types)
            push!(result.args, :(scan($t, tokens[off + $i])))
        end
    end
    return quote
        $(code...)
        return $result
    end
end

function scan(::Type{Vector{T}}, tokens::VectorLike{<:AbstractString}) where {T}
    arr = Vector{T}(undef, length(tokens))
    for (i, x) in enumerate(tokens)
        arr[i] = scan(T, x)
    end
    return arr
end

if isdefined(Base, :Memory)
    function scan(::Type{Memory{T}}, tokens::VectorLike{<:AbstractString}) where {T}
        arr = Memory{T}(undef, length(tokens))
        for (i, x) in enumerate(tokens)
            arr[i] = scan(T, x)
        end
        return arr
    end
end

function scan(::Type{Array{T}}, tokens::AbstractArray{<:AbstractString,N}) where {T,N}
    return scan(Array{T,N}, tokens)
end

function scan(::Type{Array{T,N}}, tokens::AbstractArray{<:AbstractString,N}) where {T,N}
    arr = Array{T,N}(undef, size(tokens))
    for (i, x) in enumerate(tokens)
        arr[i] = scan(T, x)
    end
    return arr
end

# A single element array/tuple of string may be scanned for a non-tuple type `T`.
function scan(::Type{T}, tokens::VectorLike{<:AbstractString}) where {T}
    n = length(tokens)
    n == 1 || throw(DimensionMismatch("expecting 1 token, got $n"))
    return scan(T, first(tokens))
end

# For non-tuple type `T` and scalar string `str`, `scan(T, str)` is like `convert(T, str)`
# if `T <: Union{AbstractString,Symbol}` and like `parse(T, str)` otherwise.
scan(::Type{T}, str::T) where {T<:AbstractString} = str
scan(::Type{T}, str::AbstractString) where {T<:AbstractString} = T(str)::T
scan(::Type{Symbol}, str::AbstractString) = Symbol(str)
function scan(::Type{T}, str::AbstractString) where {T}
    try
        val = tryparse(T, str)
        isnothing(val) || return val
    catch ex
        throw(ex isa MethodError ? ArgumentError("no method to parse string as $T") : ex)
    end
    throw(ArgumentError("cannot parse $(repr(str)) as $T"))
end

function scan(::Type{Bool}, str::AbstractString)
    s = strip(str)
    (s == "true" || s == "yes") && return true
    (s == "false" || s == "no") && return false
    throw(ArgumentError("cannot parse $(repr(str)) as Bool"))
end

#--------------------------------------------------------------------------------- DRAWING -

"""
    ds9draw([apt,] args...; kwds...)

draws something in SAOImage/DS9 application.

The specific operation depends on the type of the arguments.

"""
ds9draw(args...; kwds...) = ds9draw(default_apt(), args...; kwds...)
ds9draw(apt::AccessPoint, ::Tuple{}; kwds...) = nothing
ds9draw(apt::AccessPoint, ::T; kwds...) where {T} = error("unexpected type of argument(s): $T")

"""
    ds9draw([apt,] img::AbstractMatrix; kwds...)

displays image `img` (a 2-dimensional Julia array) in SAOImage/DS9.

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
    ds9draw([apt,] pnt; kwds...)

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
    ds9draw([apt,] box; kwds...)

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
    ds9iexam([apt], coordsys=:image; event=:button, text="", cancel=false) -> (key, x, y)
    ds9iexam([apt], :value;          event=:button, text="", cancel=false) -> (key, val)

return the position or value at the mouse cursor in SAOImage/DS9 interactively chosen by
the user.

If argument `coordsys` is `:value` or `"value"`, this function returns `(key, val)` with
`key` the key pressed or button clicked and `val` the pixel value (`NaN` if selected
position is outside image area). Otherwise, this function returns `(key, x, y)` with `(x,
y)` the coordinates of the selected position in coordinate system specified by `coordsys`.

Optional argument `apt` is to specify another access-point to a SAOImage/DS9 server than
the default one.

# Keywords

- `event` is the type of event to capture the cursor position, one of `:button`, `:key`, or
  `:any`.

- `text`, if non-empty, specifies a message to be displayed in a message dialog first.

- `cancel` specifies whether the user may cancel the operation in the dialog message, in
  which case this function returns `nothing`.

# See also

[`ds9cursor`](@ref) to retrieve `(key, x, y, val)` in `image` coordinate system.

[`ds9get`](@ref) and [`ds9message`](@ref).

"""
ds9iexam(apt::AccessPoint; kwds...) = ds9iexam(:image, apt; kwds...)
function ds9iexam(coordsys=:image, apt::AccessPoint=default_apt(); event::Symbol=:button,
                  text::AbstractString="", cancel::Bool=false, debug::Bool=false)
    event ∈ (:button, :key, :any) || throw(ArgumentError(
        "unknown event type `$(repr(event))`, must be one of `:button`, `:key`, or `:any`"))
    if isempty(text)
        XPA.set(apt, "raise")
    else
        ds9message(apt, text; cancel=cancel) || return nothing
    end
    n = coordsys ∈ (:value, "value") ? 2 : 3 # number of returned tokens
    cmd = n == 2 ? "iexam $event {\$value}" : "iexam $event coordinate $coordsys"
    debug && @info "Command: $cmd"
    str = ds9get(apt, cmd) # get result without trailing newline
    debug && @info "Answer: $(repr(str))"
    words = split(str, ' '; keepempty=true)
    length(words) ≥ 1 || return nothing
    key = (event === :button && isempty(words[1])) ? "<1>" : String(words[1])
    if n == 2
        val = scan_float(words, 2)
        return (key, val)
    else
        x = scan_float(words, 2)
        y = scan_float(words, 3)
        return (key, x, y)
    end
end

"""
    ds9cursor([apt]; event=:button, text="", cancel=false) -> (key, x, y, val)

returns the position of the mouse cursor in SAOImage/DS9 interactively chosen by the user
as a 4-tuple `(key, x, y, val)` where `key` is the key pressed or button clicked, `(x, y)`
are the image coordinates of the selected position, and `val` the corresponding pixel
value. Coordinates `x` and `y` may be `0` and `val` may be `NaN` if user selects a
position outside the image area or in an empty frame.

In SAOImage/DS9 image coordinates are similar to Julia fractional indices in ordinary
arrays. Hence, if the image pixels are also stored by `A` (an `Array`) in Julia, the
nearest position corresponds to `A[i,j]` with `(i,j) = round.(Int,(x,y))`.

Optional argument `apt` is to specify another access-point to a SAOImage/DS9 server than
the default one.

# Keywords

- `event` is the type of event to capture the cursor position, one of `:button`, `:key`, or
  `:any`.

- `text`, if non-empty, specifies a message to be displayed in a message dialog first.

- `cancel` specifies whether the user may cancel the operation in the dialog message, in
  which case this function returns `nothing`.

# See also

[`ds9iexam`](@ref) to retrieve the coordinate in another system than `image`.

[`ds9get`](@ref) and [`ds9message`](@ref).

"""
function ds9cursor(apt::AccessPoint=default_apt(); event::Symbol=:button,
                   text::AbstractString="", cancel::Bool=false)
    event ∈ (:button, :key, :any) || throw(ArgumentError(
        "unknown event type `$(repr(event))`, must be one of `:button`, `:key`, or `:any`"))
    if isempty(text)
        XPA.set(apt, "raise")
    else
        ds9message(apt, text; cancel=cancel) || return nothing
    end
    cmd = "iexam $event {\$x \$y \$value}"
    words = split(ds9get(apt, cmd), ' '; keepempty=true)
    length(words) ≥ 1 || return nothing
    key = (event === :button && isempty(words[1])) ? "<1>" : String(words[1])
    x = scan_float(words, 2)
    y = scan_float(words, 3)
    val = scan_float(words, 4)
    return (key, x, y, val)
end

scan_float(s::AbstractString) = isempty(s) ? NaN : parse(typeof(NaN), s)
scan_float(s::AbstractVector{<:AbstractString}, i::Integer) =
    checkbounds(Bool, s, i) ? scan_float(@inbounds s[i]) : NaN

#---------------------------------------------------------------------------------- LIMITS -

"""
    SAOImageDS9.limits(A, cmin=nothing, cmax=nothing) -> (lo, hi)

yields the clipping limits of values in array `A`. The result is a 2-tuple of double
precision floats `(lo,hi)`. If `cmin` is `nothing`, `lo` is the minimal finite value found
in `A` and converted to `Float64`; otherwise `lo = Float64(cmin)`. If `cmax` is `nothing`,
`hi` is the maximal finite value found in `A` and converted to `Float64`; otherwise `hi =
Float64(cmax)`.

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
to_limits(cmin::Float64, cmax::Float64) = (cmin, cmax)
to_limits(cmin::Real, cmax::Real) = to_limits(convert(Float64, cmin),
                                              convert(Float64, cmax))

"""
    finite_extrema(A) -> (vmin, vmax)

yields the minimum and maximum finite values in array `A`. The result is such that `vmin ≤
vmax` (both values being finite) unless there are no finite values in `A` in which case
`vmin > vmax`.

"""
finite_extrema(A::AbstractArray{<:Real}) = valid_extrema(isfinite, A)

"""
    finite_minimum(A) -> vmin

yields the minimum finite value in array `A`. The result is never a NaN but may be
`typemax(eltype(A))` if there are no finite values in `A`.

"""
finite_minimum(A::AbstractArray{<:Real}) = valid_minimum(isfinite, A)

"""
    finite_maximum(A) -> vmax

yields the maximum finite value in array `A`. The result is never a NaN but may be
`typemin(eltype(A))` if there are no finite values in `A`.

"""
finite_maximum(A::AbstractArray{<:Real}) = valid_maximum(isfinite, A)

"""
    valid_extrema(pred, A) -> (vmin, vmax)

yields the minimum and maximum valid values in array `A`. Valid values are those for which
predicate `pred` yields `true`. The result is such that `vmin ≤ vmax` (both values being
valid) unless there are no valid values in `A` in which case `vmin > vmax`. The predicate
function is assumed to take care of NaN's.

"""
function valid_extrema(pred, A::AbstractArray{T}) where {T}
    vmin = typemax(T)
    vmax = typemin(T)
    @inbounds for i in eachindex(A) # not @fastmath to honor NaN's behavior
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
    @inbounds for i in eachindex(A) # not @fastmath to honor NaN's behavior
        val = A[i]
        vmin = ifelse(pred(val)&(val < vmin), val, vmin)
    end
    return vmin
end
valid_minimum(::typeof(isfinite), A::AbstractRange{<:Real}) = minimum(A)

"""
    valid_maximum(A) -> vmax

yields the maximum valid value in array `A`. Valid values are those for which predicate
`pred` yields `true`. The result is a valid value but may be `typemin(eltype(A))` if there
are no valid values in `A`. The predicate function is assumed to take care of NaN's.

"""
function valid_maximum(pred, A::AbstractArray{T}) where {T}
    vmax = typemin(T)
    @inbounds for i in eachindex(A) # not @fastmath to honor NaN's behavior
        val = A[i]
        vmax = ifelse(pred(val)&(val > vmax), val, vmax)
    end
    return vmax
end
valid_maximum(::typeof(isfinite), A::AbstractRange{<:Real}) = maximum(A)


"""
    ds9wcs([apt]; useheader=true)

returns the FITS header cards defining the WCS transformation in SAOImage/DS9 frame.

# Keywords

- `useheader` specifies whether to extract WCS transformation from the FITS header.
  Otherwise, the WCS transformation is extracted from the result of the `"wcs save"`
  command.

"""
function ds9wcs(apt::AccessPoint = default_apt();
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
    ds9getregions([apt,] name=""; coords=:image, selected=false)

returns the regions defined in SAOImage/DS9 frame.

The optional argument `name` is the name of the group of regions to extract. All regions
are extracted if `name` is an empty string.

# Keywords

- `coords`: the type of coordinates to return: can be `:image`, `:physical`,
  `:fk5`, `:galactic`

The return value is a vector of 3-tuples `(shape, coordinates, properties)`,
where `shape` is a symbol indicating shape of the region, `coordinates` is an
array of coordinates, and `properties` is a dictionary with the properties of
the region. Note that the code parses as much as possible the properties:
therefore, the returned dictionary can include a variety of different value
types, depending on the keyword. The following rules applies

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
ds9getregions(name::AbstractString=""; kwds...) =
    ds9getregions(default_apt(), name; kwds...)
ds9getregions(name::AbstractString, apt::AccessPoint; kwds...) =
    ds9getregions(apt, name; kwds...)

function ds9getregions(apt::AccessPoint, name::AbstractString;
                       coords=:image, selected=false)
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

function __init__()
    ds9disconnect()
end

end # module
