using helloIBox
using Sockets
using HTTP
using Base64
using JSON
using Test





localIP =  Sockets.localhost
port = 8080
pathToIBox = "E:\\box_fail\\IBox\\IBoxLauncher.exe"
pathToIBox = "C:/Temp/IBox/IBoxLauncher.exe"
# pathToIBox = "Y:\\Yuly\\IBox\\IBoxLauncher.exe"
@testset "Access to data through IBox" begin
server_path = "E:/box_fail" # "C:/Users/yzh/Downloads/TestServer"
server_path = "C:/Users/yzh/Downloads/TestServer"

start_server(server_path; localIP = localIP, port = port)
r = HTTP.request("GET", "http://$localIP:$port/api/runIBox?res=oxy115829.dat&IBox_port=8888&IBox_path=$pathToIBox&IBox_host=$localIP")
#ЗАПРОС ДАННЫХ
r = HTTP.request("GET", "http://$localIP:$port/api/getData?res=oxy115829.dat&dataName=Freq&index=0&from=0&count=1")
Freq = reinterpret(Int32, base64decode(r.body)) |> collect
@test Freq[1]==257

r = HTTP.request("GET", "http://$localIP:$port/api/getData?res=oxy115829.dat&dataName=Ecg_1&from=0&count=20")
ecg1 = reinterpret(Int32, base64decode(r.body)) |> collect
@test length(ecg1)==20 && ecg1[1]==3099 && ecg1[20]==3062

# r = HTTP.request("GET", "http://$localIP:$port/api/getStructData?res=oxy115829.dat&dataName=/Mark/QRS&from=5847867&to=5852730&fields=QPoint,WidthQRS")



r = HTTP.request("GET", "http://$localIP:$port/api/getData?dataName=Ecg_1&from=10&to=15")
ECG = reinterpret(Int32, base64decode(r.body)) |> collect
@test ECG == [3110, 3102, 3072, 3038, 3041]
r = HTTP.request("GET", "http://$localIP:$port/api/getStructData?dataName=QRS&fields=QPoint&from=100&to=400")
QPoint = reinterpret(Int32, base64decode(r.body)) |> collect
@test QPoint == [101, 221]

r = HTTP.request("GET", "http://$localIP:$port/api/getDataTree")
tree = JSON.parse(String(r.body))
@test tree[1]["nodes"][1]["nodes"][1]["name"] == "Ecg"

r = HTTP.request("GET", "http://$localIP:$port/api/getType?dataName=QPoint")
@test String(r.body)=="Int32"
r = HTTP.request("GET", "http://$localIP:$port/api/getData?dataName=Freq&index=0&all")
Amp = reinterpret(Int32, base64decode(r.body)) |> collect



r = HTTP.request("GET", "http://$localIP:$port/api/getStructData?dataName=/Mark/QRS&from=110684&to=110694&fields=QPoint,WidthQRS")
helloIBox.unpack_vec(base64decode(r.body), Int32, Int16) == [(Int32(110629), Int16(24))]

r = HTTP.request("GET", "http://$localIP:$port/api/getStructData?res=oxy115829.dat&dataName=/Mark/QRS&from=100&to=300&fields=QPoint,WidthQRS")
QPoint =helloIBox.unpack_vec(base64decode(r.body), Int32, Int16)

r = HTTP.request("GET", "http://$localIP:$port/api/getStructData?res=oxy115829.dat&dataName=/Mark/QRS&from=100&to=300&fields=QPoint")
QPoint =helloIBox.unpack_vec(base64decode(r.body), Int32)

r = HTTP.request("GET", "http://$localIP:$port/api/getTag?res=oxy115829.dat&dataName=Ecg&index=2")
@test String(r.body)=="C1"

r = HTTP.request("GET", "http://$localIP:$port/api/getAttributes?res=oxy115829.dat&dataName=/Mark/EcgChannals/Ecg&index=1")
attr = JSON.parse(String(r.body))
@test attr["tag"] == "F" && attr["dstype"] == "signal"

#другой вариант обращения к данным
r = HTTP.request("GET", "http://$localIP:$port/api/getAttributes?res=oxy115829.dat&dataName=Ecg_2")
attr = JSON.parse(String(r.body))
@test attr["tag"] == "C1" && attr["dstype"] == "signal"


r = HTTP.request("GET", "http://$localIP:$port/api/getStructData?dataName=Ecg&index=1&from=100&to=1500")
r = HTTP.request("GET", "http://$localIP:$port/api/getData?dataName=Ecg&index=1&from=100&to=1500")

r = HTTP.request("GET", "http://$localIP:$port/api/Close")

r = HTTP.request("GET", "http://$localIP:$port/api/closeServer")

end

@testset "Manual changes" begin
portIBox = 8888
start_server(""; localIP = localIP, port = port)
r = HTTP.request("GET", "http://$localIP:$port/api/runIBox?res=oxy115829.dat&IBox_port=$portIBox&IBox_path=$pathToIBox&IBox_host=$localIP")

pathTOjson = joinpath(Base.@__DIR__, "files","oxy115829.002","command_FT0.json")
r = HTTP.request("POST", "http://$localIP:$port/api/manualChange?res=oxy115829.dat", ["Content-Type" => "application/json"], read(pathTOjson))

r = HTTP.request("GET", "http://$localIP:$port/api/getData?dataName=QRS&fields=QPoint&index=1&from=1&to=3")
QPoint = reinterpret(Int32, base64decode(r.body)) |> collect
@test QPoint == [10, 30, 50]
r = HTTP.request("GET", "http://$localIP:$port/api/getStructData?dataName=QRS&fields=QPoint,WidthQRS&from=1&to=300")
QPoint =helloIBox.unpack_vec(base64decode(r.body), Int32, Int16)

r = HTTP.request("GET", "http://$localIP:$port/api/getStructData?dataName=QRS&fields=QPoint&from=1&to=100")
QPoint = reinterpret(Int32, base64decode(r.body)) |> collect
@test QPoint == [10, 30, 50]

r = HTTP.request("GET", "http://$localIP:$port/api/getData?dataName=Ecg_2&from=0&to=100")
QPoint = reinterpret(Int32, base64decode(r.body)) |> collect


r = HTTP.request("GET", "http://$localIP:$port/api/Close")

r = HTTP.request("GET", "http://$localIP:$port/api/closeServer")

end

@testset "Additional Info" begin
portIBox = 8888
start_server(""; localIP = localIP, port = port)
r = HTTP.request("GET", "http://$localIP:$port/api/runIBox?res=oxy115829.dat&IBox_port=$portIBox&IBox_path=$pathToIBox&IBox_host=$localIP")

r = HTTP.request("GET", "http://$localIP:$port/api/getData?dataName=RRm&all")
RRm = reinterpret(Int32, base64decode(r.body)) |> collect

r = HTTP.request("GET", "http://$localIP:$port/api/getData?dataName=ClassQRS&all")
classQRS = reinterpret(Int32, base64decode(r.body)) |> collect
unClasses = unique(classQRS[findall(classQRS.!=10)])


r = HTTP.request("GET", "http://$localIP:$port/api/getData?dataName=XKoef&all")
XKoefWald = reinterpret(Int16, base64decode(r.body)) |> collect

r = HTTP.request("GET", "http://$localIP:$port/api/getData?dataName=SubClassQRS&all")
subClass = reinterpret(Int8, base64decode(r.body)) |> collect
unique(subClass)

r = HTTP.request("GET", "http://$localIP:$port/api/Close")

r = HTTP.request("GET", "http://$localIP:$port/api/closeServer")

end


r = HTTP.request("GET", "http://$localIP:$port/api/runIBox?res=oxy115829.dat&IBox_port=8888&IBox_path=$pathToIBox&IBox_host=$localIP&config=IBOpen&resName=111&arg=-open")

#
# r = HTTP.request("GET", "http://$localIP:8888/api/getStructData?from=100&to=300&dataName=/Mark/QRS&fields=QPoint,WidthQRS")
# QPoint = reinterpret(Int32, base64decode(r.body)) |> collect
#
#
# r = HTTP.request("GET", "http://$localIP:8080/api/getStructData?from=100&to=300&dataName=QRS&fields=WidthQRS")
# QPoint2 = reinterpret(UInt16, base64decode(r.body)) |> collect
#
# t = UInt8[0x65, 0x00, 0x00, 0x00, 0x17, 0x00, 0xdd, 0x00, 0x00, 0x00, 0x15, 0x00]
#
# # ###
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
