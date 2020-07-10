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

r = HTTP.request("GET", "http://$localIP:$port/api/getStructData?dataName=QRS&fields=QPoint,WidthQRS,ClassQRS,SubClassQRS&from=1&to=300")
QPoint =helloIBox.unpack_vec(base64decode(r.body), Int32, Int16, Int32, Int16)

r = HTTP.request("GET", "http://$localIP:$port/api/getType?dataName=SubClassQRS")


r = HTTP.request("GET", "http://$localIP:$port/api/getData?dataName=XKoef&all")
XKoefWald = reinterpret(Int16, base64decode(r.body)) |> collect

r = HTTP.request("GET", "http://$localIP:$port/api/getData?dataName=SubClassQRS&all")
subClass = reinterpret(Int8, base64decode(r.body)) |> collect
unique(subClass)

r = HTTP.request("GET", "http://$localIP:$port/api/Close")

r = HTTP.request("GET", "http://$localIP:$port/api/closeServer")

end

@testset "QRS tree" begin

#проверяем дерево классов QRS
server_path = "C:/Users/yzh/Downloads/TestServer"

start_server(server_path; localIP = localIP, port = port)

r = HTTP.request("GET", "http://$localIP:$port/api/runIBox?res=oxy115829.dat&IBox_port=8888&IBox_path=$pathToIBox&IBox_host=$localIP&config=IBOpen&resName=111&arg=-open")
r = HTTP.request("GET", "http://$localIP:$port/api/getQRStree")
res = String(r.body)
treeQRS = JSON.parse(res)
@test treeQRS["size"] == 91328 && treeQRS["nodes"][1]["name"]==10
r = HTTP.request("GET", "http://$localIP:$port/api/Close")

r = HTTP.request("GET", "http://$localIP:$port/api/closeServer")

end
