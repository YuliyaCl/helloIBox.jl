
include("../../src/io/pack.jl")

## simple types (numbers)

type = Int32

vbytes = UInt8[0x1, 0x0, 0x0, 0x0, 0x2, 0x0, 0x0, 0x0]
vector = Int32[1,2]

# tests:
vbytes == pack_vec(vector)
vector == unpack_vec(vbytes, type)

## composite types (tuples)

type = Tuple{Int16, Int32, Int16}
types = fieldtypes(type)

bytes = UInt8[0x1, 0x0, 0x2, 0x0, 0x0, 0x0, 0x3, 0x0]
elem = (Int16(1), Int32(2), Int16(3))

vbytes = repeat(bytes, 10)
vector = Iterators.repeated(elem, 10) |> collect

# tests:

# one element
pack_vec([elem]) == bytes
unpack_vec(bytes, types...) == [elem]

# vector
vbytes == pack_vec(vector)
vector == unpack_vec(vbytes, types...)
