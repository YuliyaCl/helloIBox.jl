using Dates
"""
`line = LinearTransform(k, b)`
`y = line(x)`
`x = inverse(line, y)`

Linear function `kx + b`
"""
struct LinearTransform #??? where {T <: Real} #
    b
    k
    inv_k # inverse of k for inverse function speedup
    LinearTransform(b, k) = new(b, k, 1/k)
end

line = LinearTransform(3.0, 10.0)

function (tr::LinearTransform)(x)
    x * tr.k + tr.b
end
function inverse(tr::LinearTransform, x)
    (x - tr.b) * tr.inv_k
end

"""
TimeGrid to represents time axes of regularly sampled signal,
sratring from `timestart` with optional start `offset`
and sampling rate `fs`
"""
struct TimeGrid
    timestart::DateTime
    fs::Float64
    offset::Int
    tr::LinearTransform # {Float64}
    TimeGrid(timestart::DateTime, fs::Union{Int64,Float64}, offset::Int = 0) =
    new(timestart, fs, offset, LinearTransform(1 - offset, fs / 1000))
end

"""
`toindex2 = index_transform(tg1, tg2)`
get function that transforms indexes of one `TimeGrid` to another.
It then can be used to transform indexes:
`i2 = toindex2(i1)`
"""
function index_transform(tg1::TimeGrid, tg2::TimeGrid)
    index_transform(tg1.tr, tg2.tr)
end
function index_transform(tr1::LinearTransform, tr2::LinearTransform)
    kk = tr1.k / tr2.k
    bb = (tr1.b - tr2.b) / tr2.k
    tr = LinearTransform(bb, kk)
    return x->floor(Int, tr(x)) # transform, then floor to integer index
end

# internal reinterpret functions
@inline time2ms(time::Period) = Dates.value(time)
@inline ms2time(msec) = Millisecond(msec)
# ms2time(msec) = DatePeriod(Dates.UTM(msec)) - transforms to absolute DateTime

"""
`ind = tg[time]`
transform relative time (period from `tg.timestart`) to index
"""
function Base.getindex(tg::TimeGrid, time::Period)
    # ind = Int(time2ms(time) * tg.fs ÷ 1000 - tg.offset + 1)
    ind = floor(Int, tg.tr(time2ms(time)))
end

"""
`ind = tg[time]`
transform absolute time to index
"""
function Base.getindex(tg::TimeGrid, time::DateTime)
    # ind = Int(time2ms(time - tg.timestart) * tg.fs ÷ 1000 - tg.offset + 1)
    ind = floor(Int, tg.tr(time2ms(time - tg.timestart)))
end

"""
`time = tg[ind]`
transform index to absolute time
"""
function Base.getindex(tg::TimeGrid, ind::Real)
    # time = ms2time((ind - 1 + tg.offset) * 1000 / tg.fs) + tg.timestart
    time = ms2time(floor(Int, inverse(tg.tr, ind))) + tg.timestart
end

"""
`time = tg[ind, Period]`
transform index to time, relative to the `tg.timestart`
"""
function Base.getindex(tg::TimeGrid, ind::Real, ::Type{Period})
    # time = ms2time((ind - 1 + tg.offset) * 1000 / tg.fs)
    time = ms2time(floor(Int, inverse(tg.tr, ind)))
end
