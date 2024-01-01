module Skipper

export skip

struct Skip{P, TX}
    pred::P
    parent::TX
end

Base.skip(pred::Function, X) = Skip(pred, X)
complement(s::Skip) = Skip(!_pred(s), parent(s))


_pred(s::Skip) = getfield(s, :pred)
Base.parent(s::Skip) = getfield(s, :parent)
parent_type(::Type{Skip{P, TX}}) where {P, TX} = TX
Base.IteratorSize(::Type{<:Skip}) = Base.SizeUnknown()
Base.IteratorEltype(::Type{<:Skip{P, TX}}) where {P, TX} = Base.IteratorEltype(TX)
Base.eltype(::Type{Skip{P, TX}}) where {P, TX} = _try_reducing_type(_eltype(TX), P)
Base.length(s::Skip) = count(!_pred(s), parent(s))

Base.IndexStyle(::Type{<:Skip{P, TX}}) where {P, TX} = Base.IndexStyle(TX)
Base.eachindex(s::Skip) = Iterators.filter(i -> !_pred(s)(@inbounds parent(s)[i]), eachindex(parent(s)))
Base.keys(s::Skip) = Iterators.filter(i -> !_pred(s)(@inbounds parent(s)[i]), keys(parent(s)))

Base.@propagate_inbounds function Base.getindex(s::Skip, I...)
    v = parent(s)[I...]
    _pred(s)(v) && throw(MissingException("the value at index $I is skipped"))
    return v
end

Base.@propagate_inbounds function Base.setindex!(s::Skip, v, I...)
    oldv = parent(s)[I...]
    _pred(s)(oldv) && throw(MissingException("existing value at index $I is skipped"))
    # _pred(s)(v) && throw(MissingException("new value to be set at index $I is skipped"))  # should it check the new value?
    return setindex!(parent(s), v, I...)
end

function Base.iterate(s::Skip, state...)
    it = iterate(parent(s), state...)
    isnothing(it) && return nothing
    item, state = it
    while _pred(s)(item)
        it = iterate(parent(s), state)
        isnothing(it) && return nothing
        item, state = it
    end
    item, state
end

Base.collect(s::Skip) = filter(Returns(true), s)

function Base.filter(f, s::Skip)
    # cannot simply use filter on parent: need to narrow eltype when possible
    y = similar(parent(s), eltype(s), 0)
    for xi in parent(s)
        if !_pred(s)(xi) && f(xi)
            push!(y, xi)
        end
    end
    y
end

function Base.map(f, A::Skip)
    a = similar(A, Core.Compiler.return_type(f, Tuple{eltype(A)}), 0)
    for x in A
        push!(a, f(x))
    end
    return a
end

Base.axes(s::Skip, args...) = axes(parent(s), args...)
Base.view(s::Skip, args...) = skip(_pred(s), view(parent(s), args...))

Base.eachslice(A::Skip; kwargs...) = map(a -> Skip(_pred(A), a), eachslice(parent(A); kwargs...))
Base.eachrow(A::Skip; kwargs...) = eachslice(A; dims=1)
Base.eachcol(A::Skip; kwargs...) = eachslice(A; dims=2)

Base.similar(::Type{T}, args...) where {T <: Skip} = similar(parent_type(T), args...)
Base.similar(A::Skip, args...) = similar(parent(A), args...)
Base._similar_for(c::Skip, ::Type{T}, itr, ::Base.SizeUnknown, ::Nothing) where {T} = similar(c, T, 0)


Base.BroadcastStyle(::Type{<:Skip}) = Broadcast.Style{Skip}()
Base.BroadcastStyle(::Broadcast.Style{Skip}, ::Broadcast.DefaultArrayStyle) = Broadcast.Style{Skip}()
Base.BroadcastStyle(::Broadcast.DefaultArrayStyle, ::Broadcast.Style{Skip}) = Broadcast.Style{Skip}()
Broadcast.materialize!(::Broadcast.Style{Skip}, dest::Skip, bc::Broadcast.Broadcasted{Style}) where {Style} =
    copyto!(dest, Broadcast.instantiate(Broadcast.Broadcasted{Style}(bc.f, bc.args, (Base.OneTo(length(dest)),))))

function Base.copyto!(dest::Skip, src::Broadcast.Broadcasted)
    destiter = eachindex(dest)
    y = iterate(destiter)
    for x in src
        isnothing(y) && throw(ArgumentError("destination has fewer elements than required"))
        @inbounds dest[y[1]] = x
        y = iterate(destiter, y[2])
    end
    return dest
end

function Base.show(io::IO, s::Skip)
    print(io, "skip(")
    show(io, _pred(s))
    print(io, ", ")
    show(io, parent(s))
    print(io, ')')
end


# some tricks to make eltype(Skip) tighter when possible

_subtract_pred_type(::Type{T}, ::Type) where {T} = T
_subtract_pred_type(::Type{T}, ::Type{typeof(ismissing)}) where {T} = Base.nonmissingtype(T)
_subtract_pred_type(::Type{T}, ::Type{typeof(isnothing)}) where {T} = Base.nonnothingtype(T)

@inline _helper_f(pred, x) = Val(pred(x))
@inline _can_be(T, P) = Core.Compiler.return_type(_helper_f, Tuple{P, T}) != Val{true}
@inline _try_reducing_type_union(::Type{T}, ::Type{P}) where {T, P} = _can_be(T, P) ? T : Union{}
@inline _try_reducing_type_union(T::Union, ::Type{P}) where {P} = Union{_try_reducing_type_union(T.a, P), _try_reducing_type_union(T.b, P)}

function _try_reducing_type(::Type{T}, ::Type{P}) where {T, P}
    Tu = _try_reducing_type_union(T, P)
    Tsub = _subtract_pred_type(T, P)    
    Treduced = Tu <: Tsub ? Tu : Tsub
    return Treduced <: T ? Treduced : T
end



# same as in FlexiMaps
_eltype(::T) where {T} = _eltype(T)
_eltype(::Type{Union{}}) = Union{}
function _eltype(::Type{T}) where {T}
    ETb = eltype(T)
    ETb != Any && return ETb
    ET = Core.Compiler.return_type(Base._iterator_upper_bound, Tuple{T})
end

end
