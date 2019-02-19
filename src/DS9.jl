#
# DS9.jl --
#
# Implement communication with SAOImage/DS9 (http://ds9.si.edu) via the XPA
# protocol.
#
#------------------------------------------------------------------------------
#
# This file is part of DS9.jl released under the MIT "expat" license.
# Copyright (C) 2016-2019, Éric Thiébaut (https://github.com/emmt).
#

module DS9

using XPA
using XPA: _join, TupleOf
using Base: ENV


# FITS pixel types.
const PixelTypes = Union{UInt8,Int16,Int32,Int64,Float32,Float64}
const PIXELTYPES = (UInt8, Int16, Int32, Int64, Float32, Float64)

"""
    DS9.connection()

yields the XPA persistent client connection used to communicate with
SAOImage/DS9 server(s).

See also [`DS9.accesspoint`](@ref), [`DS9.connect`](@ref) and
[`XPA.Client`](@ref).

"""
function connection() # @btime -> 4.383 ns (0 allocations: 0 bytes)
    if ! isopen(_CONNECTION[])
        _CONNECTION[] =  XPA.Client()
    end
    return _CONNECTION[]
end

const _CONNECTION = Ref(XPA.TEMPORARY)

const _xpa = connection # private shortcut

"""
    DS9.accesspoint()

yields the XPA access point which identifies the SAOImage/DS9 server.  This
access point can be set by calling the [`DS9.connection`](@ref) method.  An
empty string is returned if no access point has been chosen.  To automatically
connect to SAOImage/DS9 if not yet done, you can do:

    if DS9.accesspoint() == ""; DS9.connect(); end

See also [`DS9.connect`](@ref) and [`DS9.connection`](@ref).

"""
function accesspoint()
    return _ACCESSPOINT[]
end

const _ACCESSPOINT = Ref("")

# Same as `connection()` but check that a valid access point has been chosen.
function _apt() # @btime -> 3.706 ns (0 allocations: 0 bytes)
    _ACCESSPOINT[] != "" || error("call `DS9.connect(...)` first")
    return _ACCESSPOINT[]
end

"""
    DS9.connect(apt="DS9:*") -> ident

set the access point for further SAOImage/DS9 commands.  Argument `apt`
identifies the XPA access point, it can be a template string like `"DS9:*"`
which is the default value.  The returned value is the name of the access
point.

To retrieve the name of the current SAOImage/DS9 access point, call the
[`DS9.connection`](@ref) method.

See also [`DS9.accesspoint`](@ref) and [`DS9.connection`](@ref).

"""
function connect(apt::AbstractString = "DS9:*")
    cnt = 0
    rep = XPA.get(_xpa(), apt, "version"; nmax=-1)
    for i in 1:length(rep)
        XPA.has_error(rep, i) && continue # ignore errors
        cnt += 1
        if cnt == 1
            _ACCESSPOINT[] = split(XPA.get_server(rep, i);
                                   keepempty=false)[end]
        end
    end
    if cnt > 1
        _war("more than one matching SAOImage/DS9 server found, the first ",
             "one (\"", _ACCESSPOINT[], "\") was selected")
    elseif cnt == 0
        _ACCESSPOINT[] = ""
        error("no matching SAOImage/DS9 server found")
    end
    return _ACCESSPOINT[]
end

_warn(args...) = printstyled(stderr, "WARNING: ", args..., "\n";
                             color=:yellow)

# Establish the first connection.
#connect();

"""
    DS9.get([T, [dims,]] args...)

sends a "get" request to the SAOImage/DS9 server.  The request is made of
arguments `args...` converted into strings and merged with separating spaces.
An exception is thrown in case of error.

The returned value depends on the optional arguments `T` and `dims`:

* If neither `T` nor `dims` are specified, an instance of [`XPA.Reply`](@ref)
  is returned with at most one answer (see [`XPA.get`](@ref) for more details).

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

    DS9.get(Array; endian=:native) -> arr

yields the contents of current SAOImage/DS9 frame as an array (or as `nothing`
if the frame is empty). Keyword `endian` can be used to specify the byte order
of the received values (see [`DS9.byte_order`](@ref).

To retrieve the version of the SAOImage/DS9 program:

    DS9.get(VersionNumber)

See also [`DS9.connect`](@ref), [`DS9.set`](@ref) and [`XPA.get`](@ref).

"""
get(args...) =
    XPA.get(_xpa(), _apt(), _join(args);
            nmax=1, check=true)

# Yields result as a vector of numerical values extracted from the binary
# contents of the reply.
get(::Type{Vector{T}}, args...) where {T} =
    XPA.get(Vector{T}, _xpa(), _apt(), _join(args);
            nmax=1, check=true)

# Idem with given number of elements.
get(::Type{Vector{T}}, dim::Integer, args...) where {T} =
    XPA.get(Vector{T}, (dim,), _xpa(), _apt(), _join(args);
            nmax=1, check=true)

# Yields result as an array of numerical values with given dimensions
# and extracted from the binary contents of the reply.
get(::Type{Array{T,N}}, dims::NTuple{N,Integer}, args...) where {T,N} =
    XPA.get(Array{T,N}, dims, _xpa(), _apt(), _join(args);
            nmax=1, check=true)

# Idem but Array number of dimensions not specified.
get(::Type{Array{T}}, dims::NTuple{N,Integer}, args...) where {T,N} =
    get(Array{T,N}, dims, args...)

# Yields result as a single string.
get(::Type{String}, args...) =
    XPA.get(String, _xpa(), _apt(), _join(args);
            nmax=1, check=true)

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
    DS9.set(args...; data=nothing)

sends command and/or data to the SAOImage/DS9 server.  The command is made of
arguments `args...` converted into strings and merged with a separating spaces.
Keyword `data` can be used to specify the data to send.  An exception is thrown
in case of error.

As a special case:

    DS9.set(arr; mask=false, new=false, endian=:native)

set the contents of the current SAOImage/DS9 frame to be array `arr`.  Keyword
`new` can be set true to create a new frame for displyaing the array.  Keyword
`endian` can be used to specify the byte order of the values in `arr` (see
[`DS9.byte_order`](@ref).

See also [`DS9.connect`](@ref), [`DS9.get`](@ref) and [`XPA.set`](@ref).

"""
function set(args...; data=nothing)
    XPA.set(_xpa(), _apt(), _join(args);
            nmax=1, check=true, data=data)
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
    DS9.bitpix_of(x) -> bp

yields FITS bits-per-pixel (BITPIX) value for `x` which can be an array or a
type.  A value of 0 is returned if `x` is not of a supported type.

See also [`DS9.bitpix_to_type`](@ref).

"""
bitpix_of(::DenseArray{T}) where {T} = bitpix_of(T)
for T in PIXELTYPES
    bp = (T <: Integer ? 8 : -8)*sizeof(T)
    @eval bitpix_of(::Type{$T}) = $bp
    @eval bitpix_of(::$T) = $bp
end
bitpix_of(::Any) = 0

"""
    DS9.bitpix_to_type(bp) -> T

yields Julia type corresponding to FITS bits-per-pixel (BITPIX) value `bp`.
The value `Nothing` is returned if `bp` is unknown.

See also [`DS9.bitpix_of`](@ref).

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
    DS9.byte_order(endian)

yields the byte order for retrieving the elements of a SAOImage/DS9 array.
Argument can be one of the strings (or the equivalent symbol): `"big"` for most
significant byte first, `"little"` for least significant byte first or
`"native"` to yield the byte order of the machine.

See also [`DS9.get`](@ref), [`DS9.set`](@ref).

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


end # module
