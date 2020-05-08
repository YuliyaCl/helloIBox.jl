using helloIBox
using Sockets
using HTTP
using Base64
using JSON
using Test

localIP =  Sockets.localhost
port = 8080
pathToIBox = "C:/Temp/IBox/IBoxLauncher.exe"

start_server(""; localIP = localIP, port = port)
r = HTTP.request("GET", "http://$localIP:$port/api/runIBox?res=oxy115829.dat&IBox_port=8888&IBox_path=$pathToIBox&IBox_host=$localIP")
r = HTTP.request("GET", "http://$localIP:$port/api/getDataTree")
tree = JSON.parse(String(r.body))[1]

#поиск данных в дереве
info1 = findnode(tree, "EcgRecalcChannals") #запрос группы
@test info1["name"]=="EcgRecalcChannals" && length(info1["nodes"])==12
info2 = findnode(tree, "Noise_i_QRS") #запрос внутри группы более вложенное
@test info2["name"]=="Noise_i_QRS" && length(info2["nodes"])==0
info3 = findnode(tree, "Ecg_2")  #запрос внутри группы просто
@test info3["name"]=="Ecg_2" && info3["attrs"]["tag"] == "C1"

Freq = helloIBox.getData(localIP,8888,"Freq")[1] #читаем общую частоту-пока так
TimeSt = helloIBox.getData(localIP,8888,"StartTime")[1] #читаем общую частоту-пока так

attr = info3["attrs"]
attr["Freq"] = Freq
attr["TimeStart"] = TimeSt
#собираем временную сетку и лсб
TG, PhInfo = parseAttr(attr)
@test TG.fs == 257 && PhInfo.lsb.lsb == 1.063

#проверяем парсер масок
attr["Type.X"] = 1
attr["Type.S"] = 2
attr["Type.Z"] = 8
attr["datatype"] = eval(Symbol(info3["type"])) #добавляем в инфорамцию тип данных
mask = getMask(parseType(attr))
#PhysicalDataSet
DS1, dsreader,dsreader2,TG,PI,Mask = ds_new(localIP,8888,"EcgChannals","Ecg",attr)
@test isa(DS1, PhysicalDataSet) && DS1.data[1]("0","","2")==DS1.data[2]("0","","2")
@test DS1.data[1]("10","","2") == [-133, -144] && DS1.data[1]("10","12","") == [-133, -144]

#IndexDataSet
infoQPoint = findnode(tree, "QPoint")
infoQPoint["attrs"]["datatype"] = eval(Symbol(infoQPoint["type"]))
infoQPoint["attrs"]["Freq"] = Freq
infoQPoint["attrs"]["TimeStart"] = TimeSt

DSQ,dsreader,dsreader2,TG,PI,Mask = ds_new(localIP,8888,"QRS","QPoint",infoQPoint["attrs"])
@test isa(DSQ, IndexDataSet) && DSQ.data[1]("0","","2")!=DSQ.data[2]("0","","2")
@test DSQ.data[1]("1","","2") == [221, 403] && DSQ.data[2]("400","500","") == [403] #сейчас не пройдет

#IntervalDataSet
infoWidthQRS = findnode(tree, "WidthQRS")
infoWidthQRS["attrs"]["datatype"] = eval(Symbol(infoWidthQRS["type"]))
DSW,dsreader,dsreader2,TG,PI,Mask = ds_new(localIP,8888,"QRS","WidthQRS",infoWidthQRS["attrs"])
@test isa(DSW, IntervalDataSet) && DSW.data[1]("0","","2")!=DSW.data[2]("0","","2")
@test DSW.data[1]("1","","2") == [0x0015, 0x0016] && DSW.data[2]("400","500","") == [0x0016] #но тут пока не ясно


1. правок нет - просто сквозные запросы без декодирования и создания объектов
2. пришла правка - делаем объект - вычитываем данные/декодируем/сводим/сохраняем - теперь всё чтение из сведенных результатов
infoQRS = findnode(tree, "QRS") #запрос группы


#данные в интервале
# r = HTTP.request("GET", "http://127.0.0.1:8888/api/getData?dataName=QPoint&res=oxy115829.dat&count=20&from=0&index=0")
# QPoint = reinterpret(Int32, base64decode(r.body)) |> collect
#
# r = HTTP.request("GET", "http://127.0.0.1:8888/api/getStructData?dataName=QRS&fields=QPoint&res=oxy115829.dat&count=20&from=400&index=0")
# QPoint = reinterpret(Int32, base64decode(r.body)) |> collect
#
# r = HTTP.request("GET", "http://127.0.0.1:8888/apibox/getCountDataInInterval?dataName=QPoint&index=0&count=20&from=400")
# cou = reinterpret(Int32, base64decode(r.body)) |> collect

r = HTTP.request("GET", "http://127.0.0.1:8888/api/getStructData?dataName=QRS&fields=QPoint&res=oxy115829.dat&count=20&from=400&index=0")
QPoint = reinterpret(Int32, base64decode(r.body)) |> collect
r = HTTP.request("GET", "http://127.0.0.1:8888/api/getStructData?dataName=QRS&fields=WidthQRS&res=oxy115829.dat&count=500&from=0&index=0")
QPoint = reinterpret(UInt16, base64decode(r.body)) |> collect


r = HTTP.request("GET", "http://127.0.0.1:8888/api/getData?dataName=WidthQRS&res=oxy115829.dat&count=6&from=0&index=0")
QPoint = reinterpret(UInt16, base64decode(r.body)) |> collect


r = HTTP.request("GET", "http://127.0.0.1:8888/api/getStructData?dataName=QRS&fields=NoiseQRS&res=oxy115829.dat&count=500&from=0&index=0")
QPoint = reinterpret(UInt8, base64decode(r.body)) |> collect

r = HTTP.request("GET", "http://127.0.0.1:8888/api/getData?dataName=NoiseQRS&res=oxy115829.dat&count=6&from=0&index=0")
QPoint = reinterpret(UInt8, base64decode(r.body)) |> collect

d = Dict{String,Any}()
d["ss"]=1
