mutable struct QRS{T} where T
    P::T
    Q::T
    S::T
    T::T
    form
    noiseLvl::Float32
    validity::Float32
    params::Tuple{Any}
    actions::Tuple{Any}
end
function changeQ(QRS)
end

function changeS(QRS)
end

function newQRS(QRS)
end
