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
using XPA: AccessPoint, TupleOf, connection, join_arguments

using TwoDimensional

import REPL
using REPL.TerminalMenus

using Base: ENV
using Base.Iterators: Pairs

# FITS pixel types.
const PixelTypes = Union{UInt8,Int16,Int32,Int64,Float32,Float64}
const PIXELTYPES = (UInt8, Int16, Int32, Int64, Float32, Float64)

"""
    accesspoint::Uniont{XPA.AccessPoint,Nothing}

The current XPA access point to the SAOImage/DS9 server.

This access point can be set by calling the [`SAOImageDS9.connect`](@ref)
method. If no access point has been chosen this variable is set to `nothing`.
To automatically connect to SAOImage/DS9 if not yet done, you can do:

```julia
if isnothing(SAOImageDS9.accesspoint)
    SAOImageDS9.connect()
end
```

See also [`SAOImageDS9.connect`](@ref).
"""
accesspoint::Union{AccessPoint,Nothing} = nothing

"""
    _apt()

The default access point.

This function just returns [`access_point`](@ref) if this variable is set, or
establishes a new connection using [`connect`](@ref).
"""
function _apt()
    global accesspoint
    if isnothing(accesspoint)
        try
            accesspoint = connect()
        catch
            @warn """Failed to automatically connect to SAOImage/DS9. 
                Launch ds9 then do `ds9connect()`"""
        end
    end
    accesspoint
end


"""
    SAOImageDS9.connect(ident="DS9:*"; method="local") -> apt

Set the access point for further SAOImage/DS9 commands.
    
The argument `ident` identifies the XPA access point: it can be a template
string like `"DS9:*"` which is the default value or a regular expression.  The
returned value is the name of the access point.

To retrieve the name of the current SAOImage/DS9 access point, call the
[`SAOImageDS9.accesspoint`](@ref) method.
"""
function connect(ident::Union{Regex,AbstractString} = "DS9:*"; method="local", kwds...)
    global accesspoint
    if !haskey(ENV, "XPA_METHOD") && !isnothing(method)
        ENV["XPA_METHOD"] = string(method)
    end
    apt = XPA.find(ident; kwds...)
    apt === nothing && error("no matching SAOImage/DS9 server found")
    rep = XPA.get(apt, "version"; nmax=1)
    if length(rep) != 1 || ! XPA.verify(rep)
        error("XPA server at address \"" * apt *
              "\" does not seem to be a SAOImage/DS9 server")
    end
    accesspoint = apt
end


"""
    ds9select(ident="DS9:*"; method="local"; silent=false, interactive=true)

Select a DS9 window for further interactions.

If multiple DS9 windows match the `ident`, the user can select the correct
window using a simple interface; if `interactive=false` the first matching
window is selected.

!!! warning
    If `method` is not `undefined`, the environment variable `XPA_METHOD` is set
    to the corresponding string. Typically the most reliable connection is
    `local`, the default value.
"""
function ds9select(ident::Union{Regex,AbstractString}="DS9:*"; method="local",
    silent=false, interactive=true)
    global accesspoint
    if !haskey(ENV, "XPA_METHOD") && !isnothing(method)
        ENV["XPA_METHOD"] = string(method)
    end
    i = findfirst(isequal(':'), ident)
    if i === nothing
        # allow any class
        class = "*"
        name = ident
    else
        class = ident[1:i-1]
        name = ident[i+1:end]
    end
    apts = XPA.list()
    good_apts = filter(a -> (name == "*" || name == a.name) && (class == "*" || class == a.class), apts)
    if length(good_apts) == 0
        if !silent
            @error "No valid XPA access point found (server not reachable?)"
        end
        return nothing
    else
        if length(good_apts) == 1 || !interactive
            choice = 1
        else
            menu = RadioMenu(["$(p.class):$(p.name) (user=$(p.user))" for p ∈ apts])
            choice = request("Please select the correct access point:", menu)
            if choice == -1
                return nothing
            end
        end
        if !silent
            class = good_apts[choice].class
            name = good_apts[choice].name
            user = good_apts[choice].user
            @info "Connected to the XPA access point $class:$name (user=$user)"
        end
        accesspoint = good_apts[choice]
        return nothing
    end
end

"""
    ds9([name]; method="local", path="ds9")

Launch the DS9 application.

By default the application will be named using the current PID.

The `method` optional keywords is used to set the XPA communication method:
"local" is the recommended way for local executions.

This function authomaticall sets the default access point, so that all further
requests are forwarded to the newly open DS9 window.
"""
function ds9(name::String=string(getpid()); method="local", path="ds9", silent=false)
    global accesspoint
    if !haskey(ENV, "XPA_METHOD") && !isnothing(method)
        ENV["XPA_METHOD"] = string(method)
    end
    command = detach(`$path -xpa yes -xpa connect -title $name`)
    run(command; wait=false)
    if !silent
        printstyled("[ Info: "; color=Base.default_color_info, bold=true)
        print("Opening DS9")
    end
    for i ∈ 1:20
        silent || print(".")
        sleep(0.4)
        apt = XPA.find("DS9:$name")
        if !isnothing(apt)
            accesspoint = apt
            silent || println(" done")
            return
        end
    end
    silent || println(" failed")
    @warn "Timeout establishing an XPA connection."
end


"""
    get([accesspoint,] [T, [dims,]] args...)

Send a "get" request to the SAOImage/DS9 server.

The request is made of arguments `args...` converted into strings and merged
with separating spaces.

The returned value depends on the optional arguments `T` and `dims`:

* If neither `T` nor `dims` are specified, the output is converted using an
  heuristic method to suitable scalar or vector.
* If only `T` is specified, it can be:
  - `String` to return the answer as a single string;
  - `Vector{String}}` or `Tuple{Vararg{String}}` to return the answer split in
    words as a vector or as a tuple of strings;
  - `T` where `T<:Real` to return a value of type `T` obtained by parsing the
    textual answer.
  - `Tuple{Vararg{T}}` where `T<:Real` to return a value of type `T` obtained
    by parsing the textual answer;
  - `Vector{T}` where `T` is not `String` to return the binary contents of the
    answer as a vector of type `T`;
* If both `T` and `dims` are specified, `T` can be an array type like
  `Array{S}` or `Array{S,N}` and `dims` a list of `N` dimensions to retrieve
  the binary contents of the answer as an array of type `Array{S,N}`.

See also: [`SAOImageDS9.connect`](@ref), [`SAOImageDS9.set`](@ref) and `XPA.get`.
"""
function get(ap::AccessPoint, args...; kw...)
    command = join_arguments(args)
    if string(command) != ""
        r = XPA.get(ap, string(command); kw...)
        if XPA.has_errors(r)
            m = XPA.get_message(r)
            msg = strip(m[10:end])
            f = findfirst("(DS9:", msg)
            if !isnothing(f)
                msg = msg[begin:first(f)-1]
            end
            @warn "XPA $msg"
        elseif r.replies == 0
            @warn "No replies for command `$command`"
        end
        data = XPA.get_data(String, r)
        lines = filter(!isempty, split(data, "\n"))
        if isnothing(findfirst(x -> isnothing(tryparse(Int, x)), lines))
            result = tryparse.(Int, lines)
        elseif isnothing(findfirst(x -> isnothing(tryparse(Float64, x)), lines))
            result = tryparse.(Float64, lines)
        else
            result = lines
        end
        if length(result) == 0
            return nothing
        elseif length(result) == 1
            return first(result)
        else
            return result
        end
    end
    nothing
end

@inline get(args...; kw...) = get(_apt(), args...; kw...)

# Yields result as a vector of numerical values extracted from the binary
# contents of the reply.
@inline get(ap::AccessPoint, ::Type{Vector{T}}, args...; kw...) where {T} =
    XPA.get(Vector{T}, ap, join_arguments(args); kw...)

# Idem with given number of elements.
@inline get(ap::AccessPoint, ::Type{Vector{T}}, dim::Integer, args...; kw...) where {T} =
    XPA.get(Vector{T}, (dim,), ap, join_arguments(args); kw...)

# Yields result as an array of numerical values with given dimensions
# and extracted from the binary contents of the reply.
@inline get(ap::AccessPoint, ::Type{Array{T,N}}, dims::NTuple{N,Integer}, args...; kw...) where {T,N} =
    XPA.get(Array{T,N}, dims, ap, join_arguments(args); kw...)

# Idem but Array number of dimensions not specified.
@inline get(ap::AccessPoint, ::Type{Array{T}}, dims::NTuple{N,Integer}, args...; kw...) where {T,N} =
    get(ap, Array{T,N}, dims, args...; kw...)

# Yields result as a single string.
@inline get(ap::AccessPoint, ::Type{String}, args...; kw...) =
    XPA.get(String, ap, join_arguments(args); kw...)

# Yields result as a vector of strings split out of the textual contents of the
# reply.
@inline get(ap::AccessPoint, ::Type{Vector{String}}, args...; delim = isspace, keepempty::Bool=false, kw...) =
    split(chomp(get(ap, String, args...; kw...)), delim; keepempty=keepempty)

# Yields result as a tuple of strings split out of the textual contents of the
# reply.
@inline get(ap::AccessPoint, ::Type{TupleOf{String}}, args...; kw...) =
    Tuple(get(ap, Vector{String}, args...; kw...))

# Yields result as a numerical value parsed from the textual contents of the
# reply.
@inline get(ap::AccessPoint, ::Type{T}, args...; kw...) where {T<:Real} =
    _parse(T, get(ap, String, args...; kw...))::T

# Yields result as a tuple of numerical values parsed from the textual contents
# of the reply.
@inline get(ap::AccessPoint, ::Type{TupleOf{T}}, args...; kw...) where {T<:Real} =
    _parse(TupleOf{T}, get(ap, String, args...; kw...))

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
    get([accesspoint,] Array; endian=:native, kw...) 

Returns the contents of current SAOImage/DS9 frame as an array.

The keyword `endian` can be used to specify the byte order of the received
values (see [`SAOImageDS9.byte_order`](@ref)). This method retunrs`nothing` if
the frame is empty. 
"""
function get(ap::AccessPoint, ::Type{Array}; endian::Union{Symbol,AbstractString}=:native, kw...)
    T = bitpix_to_type(get(ap, Int, "fits bitpix"; kw...))
    if T === Nothing
        return nothing
    end
    dims = get(ap, TupleOf{Int}, "fits size"; kw...)
    return get(ap, Array{T}, dims, "array", byte_order(endian); kw...)
end

"""
    get([accesspoint,] VersionNumber)

Retrieve the version of the SAOImage/DS9 program.
"""
function get(ap::AccessPoint, ::Type{VersionNumber}; kw...)
    str = get(ap, String, "version"; kw...)
    return VersionNumber(split(str, " ")[end])
end

"""
    set([accesspoint,] args...; data=nothing)

Send a command and/or data to the SAOImage/DS9 server.

The command is made of arguments `args...` converted into strings and merged
with a separating spaces. Keyword `data` can be used to specify the data to
send. An exception is thrown in case of error.

See also: [`SAOImageDS9.connect`](@ref), [`SAOImageDS9.get`](@ref), and
`XPA.set`.
"""
function set(ap::AccessPoint, args...; data=nothing, kw...)
    r = XPA.set(XPA.address(ap), join_arguments(args); kw...)
    if XPA.has_errors(r)
        m = XPA.get_message(r)
        msg = strip(m[10:end])
        f = findfirst("(DS9:", msg)
        if !isnothing(f)
            msg = msg[begin:first(f)-1]
        end
        @warn "XPA $msg"
    elseif r.replies == 0
        @warn "No replies for command `$command`"
    end
    return nothing
end

@inline set(args...; kw...) = set(_apt(), args...; kw...)

"""
    set([accesspoint,] arr; mask=false, new=false, endian=:native)

Set the contents of the current SAOImage/DS9 frame to be array `arr`.

# Keywords
- `mask`: controls the DS9 mask parameters
- `new`: if `true`, a new frame is created;
- `endian`: specify the byte order of `arr` (see [`byte_order`](@ref)).
"""
function set(ap::AccessPoint, arr::DenseArray{T,N}; endian::Symbol=:native,
    mask::Bool=false, new::Bool=false, kw...) where {T<:PixelTypes,N}
    args = String["array"]
    new && push!(args, "new")
    mask && push!(args, "mask")
    set(ap, args..., _arraydescriptor(arr; endian=endian); data=arr, kw...)
end

# Convert other pixel types.
for (T, S) in ((Int8,   Int16),
               (UInt16, Float32),
               (UInt32, Float32),
               (UInt64, Float32))
    @eval set(ap::AccessPoint, arr::AbstractArray{$T,N}; kw...) where {N} =
        set(ap, convert(Array{$S,N}, arr); kw...)
end

# Convert non-dense array types.
for T in PIXELTYPES
    @eval set(ap::AccessPoint, arr::AbstractArray{$T,N}; kw...) where {N} =
        set(ap, convert(Array{$T,N}, arr); kw...)
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
    bitpix_of(x) -> bp

Return the FITS bits-per-pixel (BITPIX) value for `x`

`x` can be an array or a type. A value of 0 is returned if `x` is not of a
supported type.

See also [`bitpix_to_type`](@ref)
"""
bitpix_of(::DenseArray{T}) where {T} = bitpix_of(T)
for T in PIXELTYPES
    bp = (T <: Integer ? 8 : -8)*sizeof(T)
    @eval bitpix_of(::Type{$T}) = $bp
    @eval bitpix_of(::$T) = $bp
end
bitpix_of(::Any) = 0

"""
    bitpix_to_type(bp) -> T

Return the Julia type corresponding to FITS bits-per-pixel (BITPIX) value
`bp`.

The type `Nothing` is returned if `bp` is unknown.

See also [`bitpix_of`](@ref)
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

Return the byte order for retrieving the elements of a SAOImage/DS9 array.

The argument can be one of the strings (or the equivalent symbol): `:big` for
most significant byte first, `:little` for least significant byte first or
`:native` to yield the byte order of the machine.

See also: [`get`](@ref), [`set`](@ref).
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
    draw([accesspoint,] args...; kwds...)

Draws something in SAOImage/DS9 application.

The specific operation depends on the type of the arguments.
"""
draw(args...; kwds...) = draw(_apt(), args; kwds...)
draw(ap::AccessPoint, ::Tuple{}; kwds...) = nothing
draw(ap::AccessPoint, ::T; kwds...) where {T} = error("unexpected type of argument(s): $T")

"""
    draw([accesspoint,] img::AbstractMatrix; kwds...)

Displays image `img` (a 2-dimensional Julia array) in SAOImage/DS9.

# Keywords
- `frame`: selects the given frame number;
- `cmap`: uses the named colormap;
- `zoom`: fixes the zoom factor;
- `min` & `max`: fix the scale limits.
"""
function draw(ap::AccessPoint, img::AbstractMatrix; 
    min::Union{Real,Nothing}=nothing, max::Union{Real,Nothing}=nothing,
    cmap=nothing, frame=nothing, zoom=nothing)
    # FIXME: pack all commands into a single one.
    frame === nothing || set(ap, "frame", frame)
    zoom === nothing || set(ap, "zoom to", zoom)
    set(ap, img)
    if min !== nothing || max !== nothing
        set(ap, "scale limits", limits(img, min, max)...)
    end
    cmap === nothing || set(ap, "cmap", cmap)
    return nothing
end

# For multiple points/circles/... we just send a command to SAOImage/DS9 for
# each item to draw.  Packing multiple commands (separated by semi-columns)
# does not really speed-up things and is more complicated because there is a
# limit to the total length of an XPA command (given by XPA.SZ_LINE I guess).

"""
    draw([accesspoint,] pnt; kwds...)

Draw `pnt` as point(s) in SAOImage/DS9.

`pnt` can be a `Point`, an array, or a tuple of `Point`'s.
"""
draw(ap::AccessPoint, A::Point; kwds...) = _draw(ap, _region(Val(:point), kwds), A)
function draw(ap::AccessPoint, A::Union{Tuple{Vararg{Point}},
    AbstractArray{<:Point}}; kw...)
    cmd = _region(Val(:point), kw)
    for i in eachindex(A)
        _draw(ap::AccessPoint, cmd, A[i])
    end
end

"""
    draw([accesspoint,] box; kwds...)

Draws `box` as rectangle(s) in SAOImage/DS9.

box` can be a `BoundingBox`, an array, or a tuple of `BoundingBox`'es.
"""
draw(ap::AccessPoint, A::BoundingBox; kwds...) = _draw(ap, _region(Val(:polygon), kwds), A)
function draw(ap::AccessPoint, A::Union{Tuple{Vararg{BoundingBox}},
    AbstractArray{<:BoundingBox}}; kw...)
    cmd = _region(Val(:polygon), kw)
    for i in eachindex(A)
        _draw(ap, cmd, A[i])
    end
end

function _draw(ap::AccessPoint, cmd::NTuple{2,AbstractString}, A::Point)
    set(ap, cmd[1], A.x, A.y, cmd[2])
    nothing
end

function _draw(ap::AccessPoint, cmd::NTuple{2,AbstractString}, A::BoundingBox)
    x0, x1, y0, y1 = Tuple(A)
    set(ap, cmd[1], x0, y0, x1, y0, x1, y1, x0, y1, x0, y0, cmd[2])
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
    message([accesspoint,] message; cancel=false)

Display a dialog with the given `message`.

If `cancel=true`, a *Cancel* button is added to the dialog: in that case, the
return value is `true` or `false` depending on the button pressed by the user.
"""
message(msg::AbstractString; kwds...) =  message(_apt(), msg; kwds...)
function message(ap::AccessPoint, msg::AbstractString; cancel::Bool = false)
    btn = (cancel ? "okcancel" : "ok")
    cmd = "analysis message $btn {$msg}"
    tryparse(Int, XPA.get(String, ap, cmd)) == 1
end

"""
    select([accesspoint]; text="", cancel=false, coords=:image, event=:button)

Returns the position selected by the user.

# Keywords
- `text`: a dialog message with the given text is displayed first;
- `cancel`: if `true`, the dialog message will allow the user to cancel the
  operation (in this case this function returns `nothing`);
- `event`: the type of event to capture the cursor position, as a symbol:
  `:button`, `:key`, `:any`
- `coords`: the type of coordinates to return as a symbol: `:image`,
  `:physical`, `:fk5`, `:galactic`; if set to `:data`, this function returns
  the value of the pixel, instead of its coordinates

The function returns the tuple `(key, x, y)` or `(key, value)`, where `key` is the key
pressed, `(x, y)` are the coordinates of the point selected, and `value` the
corresponding value.
"""
function select(ap::AccessPoint=_apt(); text::AbstractString="", cancel::Bool=false,
    coords=:image, event=:button)
    if event ∉ (:button, :key, :any)
        error("Unknown event type $event")
    end
    if length(text) > 0
        message(ap, text; cancel=cancel) || return nothing
    else
        XPA.set(XPA.address(ap), "raise")
    end
    reply = XPA.get(ap, "imexam $event $(coords !== :data ? "coordinate " : "") $coords")
    data = split(XPA.get_data(String, reply))
    if event != :button
        key = data[1]
        p = parse.(Float64, @view data[2:end])
    else
        key = "<1>"
        p = parse.(Float64, data)
    end
    (key, p...)
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
