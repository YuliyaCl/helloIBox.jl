dp = `"C:/Yuly/!Code/Office/ECG_noise/dataH5/data2/MB10003190819162842s.dat"`
# dp = `"C:/Temp/oxy115829.dat"`

IBox_path = `C:/Temp/IBox/IBoxLauncher.exe`
args = `-config:IBTestWebApi -WebAPISrc[port=8888] -finalize`
command = `$IBox_path $dp $args`

@async run(command)

using helloIBox
using Sockets
using HTTP
using Base64
using Dates
localIP =  Sockets.localhost
port = 8888
r = HTTP.request("GET", "http://$localIP:$port/api/runIBox?res=MB10003190819162842s.dat&IBox_port=8888&IBox_path=$pathToIBox&IBox_host=$localIP")

using JSON
r = HTTP.request("GET", "http://$localIP:8888/api/getDataTree")
tree = JSON.parse(String(r.body))
size = tree[1]["nodes"][2]["nodes"][1]["size"] #тут EcgRecalc
numelCh = length(tree[1]["nodes"][2]["nodes"])
res = HTTP.request("GET", "http://$localIP:8888/apibox/getEntityInfo?dataName=EcgRecalcChannals&index=1")

StartTime = getData(localIP,8888,"StartTime",0,0,1,1)
res = HTTP.request("GET", "http://$localIP:8888/apibox/getEntityInfo?dataName=StartTime")
res = HTTP.request("GET", "http://$localIP:8888/apibox/getData?dataName=StartTime&index=0&from=0&count=1")
data = res.body
dataType = Time #узнаем тип данных
convertedTime = reinterpret(dataType, base64decode(data)) |> collect

Freq = getData(localIP,8888,"Freq",0,0,1,1)
dataName = Vector{String}(undef,numelCh)
attribs = Vector{Dict}(undef,numelCh)
dataECG = Array{Int32}(undef,size[1],numelCh)

for i = 1:numelCh
    if i>1
        dataName[i] = "EcgRecalc"*"_"*string(i-1)
    else
        dataName[i] = "EcgRecalc"
    end
    attribs[i] = tree[1]["nodes"][2]["nodes"][i]["attrs"]
    dataECG[:,i] = getData(localIP,8888,"EcgRecalc",i-1,0,size[1],size[1])
end
sizeQ = tree[1]["nodes"][7]["nodes"][1]["size"][1] #тут EcgRecalc
Q = getData(localIP,8888,"QPoint",0,0,sizeQ,sizeQ)
Wq = getData(localIP,8888,"WidthQRS",0,0,sizeQ,sizeQ)

using HDF5
h5open("MB10003190819162842s.004/mark.h5", "w") do file
    g = g_create(file, "Mark/EcgRecalcChannals") # create a group
    attrs(g)["grouptype"] = "series" # an attribute
    attrs(g)["Freq"] = Freq[1] # an attribute
    attrs(g)["TimeStart"] = 0.0 #пока так
    attrs(g)["Div"] = attribs[1]["div"]
    attrs(g)["Amp"] = attribs[1]["amp"]

    for i = 1:numelCh
        g[dataName[i]] = dataECG[:,i]              # create a scalar dataset inside the group
        attrs(g[dataName[i]])["dstype"] = "signal" # an attribute
        attrs(g[dataName[i]])["tag"] = attribs[i]["tag"]
    end

    gq = g_create(file, "Mark/QRS") # create a group
    attrs(gq)["grouptype"] = "segment" # an attribute
    attrs(gq)["ibegdata"] = "QPoint" # an attribute
    attrs(gq)["ienddata"] = "WidthQRS" # an attribute

    attrs(gq)["Freq"] = Freq[1] # an attribute
    attrs(gq)["TimeStart"] = 0.0 #пока так

    gq["QPoint"] = Q              # create a scalar dataset inside the group
    attrs(gq["QPoint"])["dstype"] = "index" # an attribute
    # gq["typе"] = Type              # create a scalar dataset inside the group
    # attrs(gq["typе"])["dstype"] = "feature" # an attribute

    gq["WidthQRS"] = Wq             # create a scalar dataset inside the group
    attrs(gq["WidthQRS"])["dstype"] = "interval" # an attribute
    attrs(gq["WidthQRS"])["offsetdata"] = "QPoint" # an attribute
end



h5open("MB10003190819162842s.001/mark.h5", "w") do file
    g = g_create(file, "Mark/EcgRecalcChannals") # create a group
end
