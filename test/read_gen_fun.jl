# важный костыль - кто угадает зачем?
# подсказка: туториал по generated function
foo(::Type{Type{T}}) where {T} = T

## функция для чтения произвольного тупла типов из бинарного потока

@generated function read_t(io::IOBuffer, types::Type...)
    Expr(:tuple, [Expr(:call, :read, :io, foo(i)) for i in types]...)
end
# альтернативная форма
@generated function read_t(io::IOBuffer, types...)
  args = Expr[]
  for t in types
    ex = :(read(io, (foo($t))))
    push!(args, ex)
  end
  return :(tuple($(args...)))
end

## чтение из большого бинарного массива - в вектор туплов
function read_tvector(data::Vector{UInt8}, types::Type...)
    elsize = mapreduce(sizeof, +, types)
    len = sizeof(data) ÷ elsize
    result = Vector{Tuple{types...}}(undef, len)
    io = IOBuffer(data)
    @inbounds for i in 1:len
        result[i] = read_t(io, types...)
    end
    result
end
## генерит тупл векторов заданной длины из тупла типов
@generated function tvectors(len, types...)
  Expr(:tuple, [Expr(:call, Expr(:curly, :Vector, foo(T)), :undef, :len) for T in types]...)
end
# альтернативная форма
@generated function tvectors(len, types...)
  args = Expr[]
  for T in types
    ex = :(Vector{foo($T)}(undef, len))
    push!(args, ex)
  end
  return :(tuple($(args...)))
end

## чтение из большого бинарного массива - в тупл векторов
function read_tvectors(data::Vector{UInt8}, types::Type...)
    elsize = mapreduce(sizeof, +, types)
    len = sizeof(data) ÷ elsize
    vectors = tvectors(len, types...)
    io = IOBuffer(data)
    eltypes = length(types)
    @inbounds for i in 1:len
        for j = 1:eltypes
            vectors[j][i] = read(io, types[j])
        end
    end
    vectors
end


##
bytevec = UInt8[0x01, 0x02, 0x00, 0x03, 0x00, 0x00, 0x00]
types = (Int8, Int16, Int32)
io = IOBuffer(bytevec)
x = read_t(io, types...)

types = (Int8, Int16, Int32)
elsize = mapreduce(sizeof, +, types)
bytevec = rand(UInt8, 1000 * elsize)
vec = read_tvector(bytevec, types...)

types = (Int8, Int16, Int32)
vectors = tvectors(1000, types...)

elsize = mapreduce(sizeof, +, types)
bytevec = rand(UInt8, 1000 * elsize)
vec = read_tvectors(bytevec,types...)
