
localIP =  Sockets.localhost
DG = dg_new(localIP,8888,"QRS")
DG.data["QPoint"].data[2]("0","500","500")
Int32.(DG.data["WidthQRS"].data[1]("0","10",""))

a,b,c,d = helloIBox.getSegBegsType(DG)

using StructArrays
newSeg = StructArray(ibeg = [10], iend = [20], type = [1])
helloIBox.addSeg!(DG,newSeg,"simpleAdd")



DG = dg_new(localIP,8888,"/Mark/QRS")
allObj = Dict{String,Any}()
allObj["history"] = []
allObj["state"] = 0
allObj["dataStorage"] = Dict{String,Any}()
allObj["dataStorage"]["QRS"] = DG
command1Path = joinpath(Base.@__DIR__, "files","oxy115829.002","command_FT.json")
command_FT= String(read(command1Path))
helloIBox.parseCommand(localIP, 8888, allObj,command_FT)
@test allObj["dataStorage"]["QRS"].result.QPoint[1:2]==[10,30]
@test allObj["dataStorage"]["QRS"].result.WidthQRS[1:2]==[10,15]

#добавление с расширением границ, если тип одинаковый
command1Path = joinpath(Base.@__DIR__, "files","oxy115829.002","command_FT_addRaw.json")
command_FT= String(read(command1Path))
helloIBox.parseCommand(localIP, 8888, allObj,command_FT)
@test allObj["dataStorage"]["QRS"].result.QPoint[1:2]==[10,50]
@test allObj["dataStorage"]["QRS"].result.WidthQRS[1:2]==[35,5]

#удаление сегента
command1Path = joinpath(Base.@__DIR__, "files","oxy115829.002","command_FT_delete.json")
command_FT= String(read(command1Path))
helloIBox.parseCommand(localIP, 8888, allObj,command_FT)
@test allObj["dataStorage"]["QRS"].result.QPoint[1:2]==[101,221]
@test allObj["dataStorage"]["QRS"].result.WidthQRS[1:2]==[23,21]
