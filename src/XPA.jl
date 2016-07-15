#
# XPA.jl --
#
# Implement XPA communication via the dynamic library.
#
#------------------------------------------------------------------------------
#
# This file is part of DS9.jl released under the MIT "expat" license.
# Copyright (C) 2016, Éric Thiébaut (https://github.com/emmt).
#
module XPA

export xpa_list,
       xpa_open,
       xpa_get,
       xpa_get_bytes,
       xpa_get_text,
       xpa_get_lines,
       xpa_get_words,
       xpa_set,
       xpa_config

const libxpa = "libxpa."*Libdl.dlext

const GET = UInt(1)
const SET = UInt(2)
const INFO = UInt(4)

immutable AccessPoint
    class::ASCIIString # class of the access point
    name::ASCIIString  # name of the access point
    addr::ASCIIString  # socket access method (host:port for inet,
                       # file for local/unix)
    user::ASCIIString  # user name of access point owner
    access::UInt       # allowed access
end

type Handle
    _ptr::Ptr{Void}
end

const NullHandle = Handle(C_NULL)

function xpa_open()
    ptr = ccall((:XPAOpen, libxpa), Ptr{Void}, (Ptr{Void},), C_NULL)
    if ptr == C_NULL
        error("failed to allocate a persistent XPA connection")
    end
    obj = Handle(ptr)
    finalizer(obj, obj->(obj._ptr != C_NULL && ccall((:XPAClose, libxpa), Void,
                                                     (Ptr{Void},), obj._ptr)))
    return obj
end

function xpa_list(; xpa::Handle=NullHandle)
    lst = Array(AccessPoint, 0)
    for str in xpa_get_lines("xpans"; xpa=xpa)
        arr = split(str)
        if length(arr) != 5
            warn("expecting 5 fields per access point (\"$str\")")
            continue
        end
        access = UInt(0)
        for c in arr[3]
            if c == 'g'
                access |= GET
            elseif c == 's'
                access |= SET
            elseif c == 'i'
                access |= INFO
            else
                warn("unexpected access string (\"$(arr[3])\")")
                continue
            end
        end
        push!(lst, AccessPoint(arr[1], arr[2], arr[4],
                               arr[5], access))
    end
    return lst
end

# Convert a pointer to a Julia vector and let Julia manage the memory.
_fetch{T}(ptr::Ptr{T}, nbytes::Integer) =
    ptr == C_NULL ? Array(T, 0) :
    pointer_to_array(ptr, div(nbytes,sizeof(T)), true)

_fetch{T}(::Type{T}, ptr::Ptr, nbytes::Integer) =
    _fetch(convert(Ptr{T}, ptr), nbytes)

_fetch(ptr::Ptr{Void}, nbytes::Integer) = _fetch(UInt8, ptr, nbytes)

function _fetch(::Type{ASCIIString}, ptr::Ptr{UInt8})
    if ptr == C_NULL
        str = ""
    else
        str = bytestring(ptr)
        _free(ptr)
    end
    return str
end

_free(ptr::Ptr) = (ptr != C_NULL && ccall(:free, Void, (Ptr{Void},), ptr))

doc"""
    xpa_get(src [, params...]) -> tup

retrieve data from one or more XPA access points identified by `src` (a
template name, a `host:port` string or the name of a Unix socket file) with
parameters `params` (automatically converted into a single string where the
parameters are separated by a single space).  The result is a tuple of tuples
`(data,name,mesg)` where `data` is a vector of bytes (`UInt8`), `name` is a
string identifying the server which answered the request and `mesg` is an error
message (a zero-length string `""` if there are no errors).

The following keywords are accepted:

* `nmax` specifies the maximum number of answers, `nmax=1` by default.
  Use `nmax=-1` to use the maximum number of XPA hosts.

* `xpa` specifies an XPA handle (created by `xpa_open`) for faster connections;

* `mode` specifies options in the form `"key1=value1,key2=value2"`.

"""
function xpa_get(apt::AbstractString, params...; xpa::Handle=NullHandle,
                 mode::AbstractString="", nmax::Integer=1)
    if nmax == -1
        nmax = xpa_config("XPA_MAXHOSTS")
    end
    bufs = Array(Ptr{UInt8}, nmax)
    lens = Array(Csize_t, nmax)
    names = Array(Ptr{UInt8}, nmax)
    errs = Array(Ptr{UInt8}, nmax)
    n = ccall((:XPAGet, libxpa), Cint,
              (Ptr{Void}, Cstring, Cstring, Cstring, Ptr{Ptr{UInt8}},
               Ptr{Csize_t}, Ptr{Ptr{UInt8}}, Ptr{Ptr{UInt8}}, Cint),
              xpa._ptr, apt, join(params, " "), mode,
              bufs, lens, names, errs, nmax)
    n ≥ 0 || error("unexpected result from XPAGet")
    return ntuple(i->(_fetch(bufs[i], lens[i]),
                      _fetch(ASCIIString, names[i]),
                      _fetch(ASCIIString, errs[i])), n)
end

doc"""
    xpa_get_bytes(src [, params...]; xpa=..., mode=...) -> buf

returns the `data` part of the answers received by an `xpa_get` request as a
vector of bytes.  Arguments `src` and `params...` and keywords `xpa` and `mode`
are passed to `xpa_get` limiting the number of answers to be at most one.  An
error is thrown if `xpa_get` returns a non-empty error message.
"""
function xpa_get_bytes(args...; xpa::Handle=NullHandle, mode::AbstractString="")
    (data, name, mesg) = xpa_get(args...; xpa=xpa, mode=mode, nmax=1)[1]
    length(mesg) > 0 && error(mesg)
    return data
end

doc"""
    xpa_get_text(src [, params...]; xpa=..., mode=...) -> str

converts the result of `xpa_get_bytes` into a single string.
"""
xpa_get_text(args...; kwds...) =
    bytestring(xpa_get_bytes(args...; kwds...))

doc"""
    xpa_get_lines(src [, params...]; keep=false, xpa=..., mode=...) -> arr

splits the result of `xpa_get_text` into an array of strings, one for each
line.  Keyword `keep` can be set `true` to keep empty lines.
"""
xpa_get_lines(args...; keep::Bool=false, kwds...) =
    split(chomp(xpa_get_text(args...; kwds...)), r"\n|\r\n?", keep=keep)

doc"""
    xpa_get_words(src [, params...]; xpa=..., mode=...) -> arr

splits the result of `xpa_get_text` into an array of words.
"""
xpa_get_words(args...; kwds...) =
    split(xpa_get_text(args...; kwds...), r"[ \t\n\r]+", keep=false)

doc"""
    xpa_set(dest [, params...]; data=nothing) -> tup

send `data` to one or more XPA access points identified by `dest` with
parameters `params` (automatically converted into a single string where the
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

* `xpa` specifies an XPA handle (created by `xpa_open`) for faster connections;

* `mode` specifies options in the form `"key1=value1,key2=value2"`.

* `check` specifies whether to check for errors.  If this keyword is set true,
  an error is thrown for the first non-empty error message `mesg` encountered
  in the list of answers.

"""
function xpa_set(apt::AbstractString, params...;
                 data::Union{DenseArray,Void}=nothing,
                 xpa::Handle=NullHandle, mode::AbstractString="",
                 nmax::Integer=1, check::Bool=false)
    buf::Ptr{Void}
    len::Int
    if isa(data, Void)
        buf = C_NULL
        len = 0
    else
        @assert isbits(eltype(data))
        buf = pointer(data)
        len = sizeof(data)
    end
    if nmax == -1
        nmax = xpa_config("XPA_MAXHOSTS")
    end
    names = Array(Ptr{UInt8}, nmax)
    errs = Array(Ptr{UInt8}, nmax)
    n = ccall((:XPASet, libxpa), Cint,
              (Ptr{Void}, Cstring, Cstring, Cstring, Ptr{Void},
               Csize_t, Ptr{Ptr{UInt8}}, Ptr{Ptr{UInt8}}, Cint),
              xpa._ptr, apt, join(params, " "), mode,
              buf, len, names, errs, nmax)
    n ≥ 0 || error("unexpected result from XPASet")
    tup = ntuple(i->(_fetch(ASCIIString, names[i]),
                     _fetch(ASCIIString, errs[i])), n)
    if check
        for (name, mesg) in tup
            length(mesg) > 0 && error(mesg)
        end
    end
    return tup
end


# These default values are defined in "xpap.h" and can be changed by
# user environment variable:
_DEFAULTS = Dict{AbstractString,Any}("XPA_MAXHOSTS" => 100,
                                     "XPA_SHORT_TIMEOUT" => 15,
                                     "XPA_LONG_TIMEOUT" => 180,
                                     "XPA_CONNECT_TIMEOUT" => 10,
                                     "XPA_TMPDIR" => "/tmp/.xpa",
                                     "XPA_VERBOSITY" => true,
                                     "XPA_IOCALLSXPA" => false)

function xpa_config(key::AbstractString)
    global _DEFAULTS, ENV
    haskey(_DEFAULTS, key) || error("unknown XPA parameter \"$key\"")
    def = _DEFAULTS[key]
    if haskey(ENV, key)
        val = haskey(ENV, key)
        return (isa(def, Bool) ? (parse(Int, val) != 0) :
                isa(def, Integer) ? parse(Int, val) : val)
    else
        return def
    end
end

function xpa_config{T<:Union{Integer,Bool,AbstractString}}(key::AbstractString,
                                                           val::T)
    global _DEFAULTS, ENV
    old = xpa_config(key) # also check validity of key
    def = _DEFAULTS[key]
    if isa(def, Integer) && isa(val, Integer)
        ENV[key] = dec(val)
    elseif isa(def, Bool) && isa(val, Bool)
        ENV[key] = (val ? "1" : "0")
    elseif isa(def, AbstractString) && isa(val, AbstractString)
        ENV[key] = val
    else
        error("invalid type for XPA parameter \"$key\"")
    end
    return old
end

xpa_config(key::Symbol) = xpa_config(string(key))
xpa_config(key::Symbol, val) = xpa_config(string(key), val)

end # module
