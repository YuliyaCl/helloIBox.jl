module helloIBox
using JSON
using HTTP
using Base64
using StructArrays
using Dates
using Sockets

export  start_server, getData, getTag, getDataTree,getChildsCount,
        getAttr, getStructData,
        dg_new

include("io/pack.jl")
include("helloServer.jl")
include("IBoxAPI.jl")
include("timeseries.jl")
include("segments.jl")
include("features.jl")
include("datasets.jl")
include("undoredo.jl")
include("datagroup.jl")
include("manualmarks.jl")


end # module
