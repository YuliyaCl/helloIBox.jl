@testset "Undo-redo" begin

localIP =  Sockets.localhost
port = 8080
pathToIBox = "C:/Temp/IBox/IBoxLauncher.exe"
#проверяемм Undo-redo
server_path = "C:/Users/yzh/Downloads/TestServer"

start_server(server_path; localIP = localIP, port = port)

r = HTTP.request("GET", "http://$localIP:$port/api/runIBox?res=oxy115829.dat&IBox_port=8888&IBox_path=$pathToIBox&IBox_host=$localIP&config=IBOpen&resName=111&arg=-open")


DG = dg_new(localIP,8888,"QRS")
allObj = Dict{String,Any}()
allObj["history"] = []
allObj["state"] = 0
allObj["dataStorage"] = Dict{String,Any}()
allObj["dataStorage"]["QRS"] = DG

command1 = String(read(joinpath(Base.@__DIR__, "files","oxy115829.002","command_FT.json")))
command2 = String(read(joinpath(Base.@__DIR__, "files","oxy115829.002","command_FT_addRaw.json")))
command3 = String(read(joinpath(Base.@__DIR__, "files","oxy115829.002","command_FT_delete.json")))

helloIBox.parseCommand(localIP, 8888, allObj,command1)
helloIBox.parseCommand(localIP, 8888, allObj,command2)
helloIBox.parseCommand(localIP, 8888, allObj,command3)

@test allObj["dataStorage"]["QRS"].result.QPoint[1:2]==[101,221]
@test allObj["dataStorage"]["QRS"].result.WidthQRS[1:2]==[23,21]
#делаем отмены до упора и потом реду
helloIBox.undo!(allObj,localIP, 8888)

@test DG.result.QPoint[1:2]==[10,50]
@test DG.result.WidthQRS[1:2]==[35,5]
@test allObj["state"] == 2

helloIBox.undo!(allObj,localIP, 8888)
@test DG.result.QPoint[1:2]==[10,30]
@test DG.result.WidthQRS[1:2]==[10,15]

helloIBox.undo!(allObj,localIP, 8888)
@test DG.result==[]

helloIBox.redo!(allObj,localIP, 8888)
@test DG.result.QPoint[1:2]==[10,30]
@test DG.result.WidthQRS[1:2]==[10,15]
helloIBox.redo!(allObj,localIP, 8888)
helloIBox.redo!(allObj,localIP, 8888)
@test allObj["dataStorage"]["QRS"].result.QPoint[1:2]==[101,221]
@test allObj["dataStorage"]["QRS"].result.WidthQRS[1:2]==[23,21]


helloIBox.undo!(allObj,localIP, 8888)
helloIBox.undo!(allObj,localIP, 8888)
#если прилетает новая команда после нескольких undo, то история должна перезатереться!

helloIBox.parseCommand(localIP, 8888, allObj,command3)
@test allObj["history"]==[command1, command3]

# helloIBox.getStructData(DG,1,500,"QPoint")
r = HTTP.request("GET", "http://$localIP:$port/api/closeServer")

end

@testset "Serder undo-redo" begin


    portIBox = 8888
    start_server(server_path; localIP = localIP, port = port)
    r = HTTP.request("GET", "http://$localIP:$port/api/runIBox?res=oxy115829.dat&IBox_port=8888&IBox_path=$pathToIBox&IBox_host=$localIP&config=IBOpen&resName=111&arg=-open")

    r = HTTP.request("GET", "http://$localIP:$port/api/getData?dataName=QPoint&index=0&from=0&to=3")
    QPoint = reinterpret(Int32, base64decode(r.body)) |> collect
    @test QPoint == [101, 221, 403]


    pathTOjson = joinpath(Base.@__DIR__, "files","oxy115829.002","command_FT0.json")
    r = HTTP.request("POST", "http://$localIP:$port/api/manualChange?res=oxy115829.dat", ["Content-Type" => "application/json"], read(pathTOjson))
    r = HTTP.request("GET", "http://$localIP:$port/api/getData?dataName=QRS&fields=QPoint&index=0&from=1&to=4")

    QPoint = reinterpret(Int32, base64decode(r.body)) |> collect
    @test QPoint == [10, 30, 50,101]

    r = HTTP.request("GET", "http://$localIP:$port/api/undo")
    r = HTTP.request("GET", "http://$localIP:$port/api/getStructData?dataName=QRS&fields=QPoint&from=1&to=500")
    r = HTTP.request("GET", "http://$localIP:$port/api/redo")
    r = HTTP.request("GET", "http://$localIP:$port/api/getStructData?dataName=QRS&fields=QPoint&from=1&to=500")
    QPoint = reinterpret(Int32, base64decode(r.body)) |> collect
    @test QPoint == [10,30,50,101, 221, 403]

    r = HTTP.request("GET", "http://$localIP:$port/api/closeServer")


end
