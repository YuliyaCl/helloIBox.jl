r = HTTP.request("GET", "http://$localIP:$port/api/runIBox?res=oxy115829.dat&IBox_port=8888&IBox_path=$pathToIBox&IBox_host=$localIP&config=IBOpen&resName=111&arg=-open")
r = HTTP.request("GET", "http://$localIP:$port/api/getDataTree")
tree = JSON.parse(String(r.body))[1]

r = HTTP.request("GET", "http://127.0.0.1:8888/api/getData?dataName=QPoint&all")
QPoint = reinterpret(Int32, base64decode(r.body)) |> collect


r = HTTP.request("GET", "http://127.0.0.1:8888/api/getData?dataName=ClassQRS&all")
Class = reinterpret(Int32, base64decode(r.body)) |> collect
unCl = unique(Class)
QPoint = QPoint[1:length(Class)]


r = HTTP.request("GET", "http://127.0.0.1:8888/api/getData?dataName=SubClassQRS&all")
SubClass = reinterpret(Int16, base64decode(r.body)) |> collect
unSubCl = unique(SubClass)


treeClasses = Dict{String,Any}()
treeClasses["nodes"] = []
treeClasses["name"] = "allClasses"
treeClasses["size"] = length(Class)

for i = 1:length(unCl)
    isCl = Class.==unCl[i]
    node =  Dict{String,Any}()
    node["nodes"] = []
    node["name"] = unCl[i]
    node["size"] = sum(isCl)
    node["QPoint"] = QPoint[isCl]
    for j = 1:length(unSubCl) #теперь добавляем подклассы
        isSubCl= (SubClass.== unSubCl[j]) .& isCl
        subnode =  Dict{String,Any}()
        subnode["nodes"] = []
        subnode["name"] = unSubCl[j]
        subnode["size"] = sum(isSubCl)
        subnode["QPoint"] = QPoint[isSubCl]
        push!(node["nodes"],subnode)
    end
    push!(treeClasses["nodes"],node)
end


result = JSON.json(treeClasses)
