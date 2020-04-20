using helloIBox
using Sockets
using HTTP
using Base64
localIP =  Sockets.localhost
port = 8080
start_server(""; localIP = localIP, port = port)
r = HTTP.request("GET", "http://$localIP:$port/api/runIBox?res=oxy115829.dat")
r = HTTP.request("GET", "http://$localIP:$port/api/getData?res=oxy115829.dat&dataName=Ecg_1&from=0&to=10&count=20")
r = HTTP.request("GET", "http://$localIP:$port/api/getData?res=oxy115829.dat&dataName=QPoint&index=0&from=0&to=10&count=20")

r = HTTP.request("GET", "http://$localIP:$port/api/getDataTag?res=oxy115829.dat&dataName=Ecg")
r = HTTP.request("GET", "http://$localIP:$port/api/getDataTag?res=oxy115829.dat&dataName=Ecg&index=2")
r = HTTP.request("GET", "http://$localIP:$port/api/getDataTag?res=oxy115829.dat&dataName=Ecg_2")


r = HTTP.request("GET", "http://$localIP:$port/api/closeServer")
###
# param = Dict()
# param["dataName"]="Ecg"
#
# param["index"]="0"
# param["from"]="0"
# param["to"]="100"
# param["count"] ="1000"
# #
# data = getData(localIP,"8888",param)

# ## изучаю как там с запросом детей
# TopDataName = "QRS"
#
# res = HTTP.request("GET", "http://$localIP:8888/apibox/getChildsCount?dataName=$TopDataName&index=0")
# channelsCount_st = String(res.body)
# channelsCount = parse(Int,channelsCount_st)
# res = HTTP.request("GET", "http://$localIP:8888/apibox/getChildsCount?dataName=Validity_i_QRS&index=0")
#
#
# #получаем имена каналов
# chNames = []
# child_names = []
# for ch=0:channelsCount-1
#     res = HTTP.request("GET", "http://$localIP:8888/apibox/getChildsName?dataName=$TopDataName&index=$ch")
#     child_name = String(res.body)
#     push!(child_names,child_name)
#     res = HTTP.request("GET", "http://$localIP:8888/apibox/getCountTyp?dataName=$child_name")
#
#
#     res = HTTP.request("GET", "http://$localIP:8888/apibox/getTag?dataName=$child_name&index=$ch")
#     chName = String(res.body)
#     push!(chNames,chName)
# end
#
#
# #информация о данных
# res = HTTP.request("GET", "http://$localIP:8888/apibox/getEntityInfo?dataName=QRS&index=1")
# res = HTTP.request("GET", "http://$localIP:8888/apibox/getChildsCount?dataName=QRS&index=0")
#
# using JSON
# r = HTTP.request("GET", "http://$localIP:8888/api/getDataTree")
# tree = JSON.parse(String(r.body))
#
# svec = base64encode([1,2,3,4,5])
# data = reinterpret(Int, base64decode(svec)) |> collect
# toInt = map(x->convert(Int64,x), svec)
#
# data = getData(localIP,8888,"/Mark/EcgChannals/Ecg",0,0,100,300)
# toInt = reinterpret(Int32, base64decode(data)) |> collect
#
# data = getData(localIP,8888,"Ecg",1,0,10,30)
#
# toInt = reinterpret(String, base64decode(info)) |> collect
#
# string(base64decode(info))
#
# tag = getData("RSI",localIP,8888)
# attr = getAttr("Ecg",localIP,8888) #не работает=()
# res = HTTP.request("GET", "http://$localIP:8888/api/getAttributes?res=oxy115829.dat&dataName=/Mark/EcgChannals/Ecg")
# res = HTTP.request("GET", "http://$localIP:8888/api/getAttributes?res=oxy115829.dat&dataName=/Mark/EcgChannals")
#
# res = HTTP.request("GET", "http://$localIP:8888/apibox/getData?dataName=RSI&index=0&from=0&count=10")
# toInt = reinterpret(Char, base64decode(res.body)) |> collect
using Test
data = getData(localIP,8888,"WidthQRS",0,0,10,10)
att = helloIBox.getAttr(localIP,8888,"WidthQRS")
@test att["dstype"]=="interval"
@test att["offsetdata"]=="QPoint"
data = getData(localIP,8888,"QPoint",0,0,1,1)

tag = getTag(localIP,8888,"Ecg")
@test tag=="L"
# datapath = "Ecg_1"
# param = Dict()
# if length(split(datapath,"_"))>1
#     param["index"] = split(datapath,"_")[2]
#     datapath = split(datapath,"_")[1]
# end
tag = getTag(localIP,8888,"Ecg1")

dataCount = helloIBox.getCountDataInInterval(localIP,8888,"QPoint",0,0,10,1000)

base64decode(data)
data = Array{UInt8}(undef,2)
data=[0x2d,0x31]
@info [data]
