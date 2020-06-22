# паковка и распаковка массивов в байтовые массивы и обратно

"""
pack: vector of numbers => byte vector
"""
pack_vec(vect::Vector{T}) where T <: Number = reinterpret(UInt8, vect) |> collect


"""
pack: tuple of vectors => byte vector
* сейчас сделано с промежуточной аллокацией памяти
"""
# This works because, unlike for any other type,
# tuples are covariant in their subtypes
pack_vec(vecs::Tuple{Vararg{Vector}}) = zip(vecs...) |> collect |> pack_vec

"""
pack: vector of tuples => byte vector
"""
@generated function pack_vec(vect::Vector{T}) where T <: Tuple
    types = fieldtypes(T)
    exprs = Expr[]
    k = 0
    for T in types
        k += 1
        ex = quote
            let
                p::Ptr{$T} = pointer(result, ind)
                unsafe_store!(p, x[$k], 1)
                ind += sizeof($T)
            end
        end
        push!(exprs, ex)
    end
    loop_unroll = Expr(:block, exprs...)

    out_expr = quote
        elsize = reduce(+, sizeof.($types))
        len = length(vect) * elsize
        result = Vector{UInt8}(undef, len)

        GC.@preserve result begin
            ind::Int = 1
            @inbounds for x in vect
                $loop_unroll
            end
        end
        return result
    end

    return out_expr
end

# inner function to get type inside generated function
_gettype(::Type{Type{T}}) where {T} = T

"""
unpack: byte vector => vector of numbers
"""
unpack_vec(vect::Vector{UInt8}, type::Type) = reinterpret(type, vect) |> collect

"""
unpack: byte vector => vector of tuples
"""
@generated function unpack_vec(vect::Vector{UInt8}, types...)
    exprs = Expr[]
    for T in types
        ex = quote
            let
                p::Ptr{_gettype($T)} = pointer(vect, ind)
                x = unsafe_load(p)
                ind += sizeof(_gettype($T))
                x
            end
        end
        push!(exprs, ex)
    end
    loop_unroll = :(tuple($(exprs...)))

    out_expr = quote
        elsize = reduce(+, sizeof.(types))
        len = sizeof(vect) ÷ elsize
        result = Vector{Tuple{types...}}(undef, len)

        GC.@preserve vect begin
            ind::Int = 1
            @inbounds for i in 1:len
                result[i] = $loop_unroll
            end
        end
        return result
    end

    return out_expr
end

"""
unpack: byte vector => tuple of vectors
* такого пока что нет - надо преобразовывать отдельно в StructArray
"""
