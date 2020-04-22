using Test
@testset "IBox commands test" begin
data = getData(localIP,8888,"WidthQRS",0,0,10,10)
att = helloIBox.getAttr(localIP,8888,"WidthQRS")
@test att["dstype"]=="interval"
@test att["offsetdata"]=="QPoint"
data = getData(localIP,8888,"QPoint",0,0,1,1)
@test data == [101]

data = getData(localIP,8888,"WidthQRS",0,0,1,30)
@test data[1] == 0x0017

tag = getTag(localIP,8888,"Ecg")
@test tag=="L"

dataCount = helloIBox.getCountDataInInterval(localIP,8888,"QPoint",0,0,0,1000)
@test dataCount==6

amp = getData(localIP,8888,"AmpECG",0,0,1,1)
@test amp[1]==1063
Fr = getData(localIP,8888,"Freq",0,1,1)
@test Fr[1]==257
end


#
# fields = "QPoint,WidthQRS"
# allFields = split(fields,",")
# alldataType = [] #собираем типы данных, чтобы работать с ними
# for f in allFields
#     push!(alldataType, helloIBox.getDataType(localIP,8888,string(f))) #узнаем тип данных
# end
