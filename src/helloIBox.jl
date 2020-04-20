module helloIBox
using JSON
using HTTP
using Base64
using StructArrays
using Dates
using Sockets

export  start_server, getData, getTag, getDataTree,getChildsCount, getAttr

include("helloServer.jl")
include("IBoxAPI.jl")
include("timeseries.jl")
include("datasets.jl")


end # module
