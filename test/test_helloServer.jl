using helloIBox
using Sockets
using HTTP
using Base64
using Test

localIP =  Sockets.localhost
port = 8080
@testset "Access to data through IBox" begin

start_server(""; localIP = localIP, port = port)
r = HTTP.request("GET", "http://$localIP:$port/api/runIBox?res=oxy115829.dat&IBox_port=8888&IBox_path=C:/Temp/IBox/IBoxLauncher.exe&IBox_host=$localIP")
r = HTTP.request("GET", "http://$localIP:$port/api/killIBox?res=oxy115829.dat")
#ЗАПРОС ДАННЫХ
r = HTTP.request("GET", "http://$localIP:$port/api/getData?res=oxy115829.dat&dataName=Freq&index=0&from=0&count=1")
Freq = reinterpret(Int32, base64decode(r.body)) |> collect
@test Freq[1]==257

r = HTTP.request("GET", "http://$localIP:$port/api/getData?res=oxy115829.dat&dataName=Ecg_1&from=0&count=20")
ecg1 = reinterpret(Int32, base64decode(r.body)) |> collect
@test length(ecg1)==20 && ecg1[1]==3099 && ecg1[20]==3062

#данные в интервале
r = HTTP.request("GET", "http://$localIP:$port/api/getData?res=oxy115829.dat&dataName=QPoint&index=0&from=0&count=300")
QPoint = reinterpret(Int32, base64decode(r.body)) |> collect
@test QPoint == [101, 221]

#данные читаются "чистяком"
r = HTTP.request("GET", "http://$localIP:$port/api/getData?res=oxy115829.dat&dataName=WidthQRS&index=0&from=0&count=30")
WidthQRS = reinterpret(UInt16, base64decode(r.body)) |> collect
@test length(WidthQRS) == 30 && WidthQRS[1] == 0x0017

#данные "чистяком"
r = HTTP.request("GET", "http://$localIP:$port/api/getDataRaw?res=oxy115829.dat&dataName=QPoint&index=0&from=0&count=300")
QPoint = reinterpret(Int32, base64decode(r.body)) |> collect
@test length(QPoint) == 300 #берет оригинальные точки

r = HTTP.request("GET", "http://$localIP:$port/api/getDataTag?res=oxy115829.dat&dataName=Ecg&index=2")
@test String(r.body)=="C1"
r = HTTP.request("GET", "http://$localIP:$port/api/getDataTag?res=oxy115829.dat&dataName=Ecg_2")
@test String(r.body)=="C1"

r = HTTP.request("GET", "http://$localIP:$port/api/getDataTree")
tree = JSON.parse(String(r.body))
@test tree[1]["nodes"][1]["nodes"][1]["name"] == "Ecg"

r = HTTP.request("GET", "http://$localIP:$port/api/closeServer")
end




# ###
# param = Dict()
# param["dataName"]="Ecg"
#
# param["index"]="0"
# param["from"]="0"
# param["to"]="100"
# param["count"] ="1000"
# param["count"]  = 1
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
