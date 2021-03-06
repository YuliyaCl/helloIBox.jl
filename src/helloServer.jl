const BAREHTML = "<head><meta http-equiv=\"Content-Type\" content=\"text/html; charset=UTF-8\">
 <title>Empty.html</title></head><body></body></html>"
import Sockets
const BODY =  "<body><p>API:
                <p>/api/runIBox
                <p>/api/getDataTree/
                </body>"
"""
структура для хранения константного состояния сервера
"""
struct ServerState
    path::String
    obj::Dict #храним все объекты на основе файла
end
ServerState() = ServerState("")
using HTTP
"""
Формирование стандартной шапки HTTP-ответа
"""
@inline function addResponseHeader(res)
    push!(res.headers, "Connection" => "keep-alive")
    push!(res.headers, "Access-Control-Allow-Origin" => "*")
    push!(res.headers, "Content-Type" => "text/html; charset=utf-8")
    push!(res.headers, "Access-Control-Allow-Methods" => "POST, GET")
    res
end

"""
корневой запрос - показать страницу с описанием API
"""
handle(reg::HTTP.Request) = replace(BAREHTML, "<body></body>" => BODY) |> HTTP.Response


"""
`filename, filepath, datapath, param = parse_uri(reqstr, srvpath)`

Входные аргументы:
`reqstr` - строка запрсоа
`srvpath` - путь на сервере

Выходные аргументы:
`filename` - имя запрошенной записи
`filepath` - полный путь hdf5-файла на сервере
`datapath` - путь к данным внутри hdf-файла
`param` - параметры запроса (словарь)
"""
function parse_uri(reqstr::AbstractString, srv::ServerState)
    uri = parse(HTTP.URI, reqstr)
    param = HTTP.URIs.queryparams(uri)
    args = HTTP.URIs.splitpath(uri.path)

    if !haskey(param,"res")
        #старый вариант работы
        filename = "" # omit /api/command/...
        filepath = srv.obj["filepath"] #
    else
        filepath = joinpath(srv.path, param["res"])
        filename = basename(filepath)

        srv.obj["filename"]  = filename
        srv.obj["filepath"]  = filepath
    end

    if haskey(param,"dataName")
        datapath = string(param["dataName"])
        # собираем или ищем датагруппу
    else
        datapath = ""
    end
    # manualpath = joinpath(srvpath, filename, "manual_mark.hdf")
    return filename, filepath, datapath, param
end

#стартуем бокс на файле данных
function runIBox(srv::ServerState, req::HTTP.Request)
    filename, filepath, datapath, param = parse_uri(req.target, srv)

    # @info filename, filepath, datapath, param

    IBox_path = param["IBox_path"]
    port = param["IBox_port"]

    if haskey(param, "config") #какую конфигурацию бокса брать
        conf = param["config"]
    else
        conf = "ConfigClsWebApi"
    end
    if haskey(param, "resName") #в какую разметку писать или из какой читать
        resName = param["resName"]
    else
        resName = "000"
    end
    if haskey(param, "arg") #если надо открыть, то пишем -open
        arg = param["arg"]
    else
        arg = ""
    end

    out = "Тут тип загрузился бокс"
    # args = `-config:IBTestWebApi -WebAPISrc[port=$port|debug=true] -finalize -res:000`

    args = `-config:$conf -WebAPISrc[port=$port|debug=true] -finalize -res:$resName $arg`

    # args = `-config:IBOpen -WebAPISrc[port=$port|debug=true] -finalize -res:000 -open`

    command = `$IBox_path $filepath $args`
    @show command
    @async run(command)
    out = "Бокс запущен..."
    srv.obj["IBox_port"] = port
    srv.obj["IBox_path"] = IBox_path
    srv.obj["IBox_host"] = IPv4(param["IBox_host"])

    res = out |> HTTP.Response |> addResponseHeader
end

#закрываем бокс на файле данных
function Close(srv::ServerState, req::HTTP.Request)
    filename, filepath, datapath, param = parse_uri(req.target, srv)

    # @info filename, filepath, datapath, param

    localIP = srv.obj["IBox_host"]
    port = srv.obj["IBox_port"]

    r = HTTP.request("GET", "http://$localIP:$port/api/Close")
    out = "Бокс закрыт..."

    res = out |> HTTP.Response |> addResponseHeader
end

function redirectRequest(srv::ServerState, req::HTTP.Request)
    filename, filepath, datapath, param = parse_uri(req.target, srv)
    regstr = req.target #само содержание запроса
    @info filename, filepath, datapath, param
    if haskey(srv.obj["dataStorage"],datapath) #был объект, значит были ручные правки - читаем из него

        DG = srv.obj["dataStorage"][datapath]
        if haskey(param,"from")
            from = parse(Int32,param["from"])
        end
        if haskey(param,"to")
            to = parse(Int32,param["to"])
        end

        if occursin("getData",regstr)
            data = getData(DG,from,to,param["fields"])
        elseif occursin("getStructData",regstr)
            data = getStructData(DG,from,to,param["fields"])
        end
        if isa(data,Array{Any})
            t_data = (data...,)
        else
            t_data = data
        end
        println(data)
        if !isempty(data)
            out = pack_vec(t_data) |> base64encode
        else
            out = "null"
        end
        println("Объект имеется")
    else #объекта нет, значит читаем напрямую
        port = srv.obj["IBox_port"]
        localIP = srv.obj["IBox_host"]
        println("http://$localIP:$port$regstr")
        r = HTTP.request("GET", "http://$localIP:$port$regstr")
        # @info r
        out = r.body
    end

    res = out |> HTTP.Response |> addResponseHeader
end

#бокс уже должен быть запущен! читаем данные из бокса по getData
function getData(srv::ServerState, req::HTTP.Request)
    filename, filepath, datapath, param = parse_uri(req.target, srv)

    @info filename, filepath, datapath, param
    port = srv.obj["IBox_port"]
    localIP = srv.obj["IBox_host"]

    data = getData(localIP,port,param)
    if !isempty(data)
        out = pack_vec(data) |> base64encode
    else
        out = "null" # gvg: это стандартный вывод?
    end

    res = out |> HTTP.Response  |> addResponseHeader
end

"""
запись ручных правок
{
    "chName": "",
    "targetData": "",
    "command": {
        "id": "",
        "args": {
            "ibeg": [],
            "iend": [],
            "type": [""],
            "mode": ""
        }
    }
}
"""
function manualChange(srv::ServerState, req::HTTP.Request)
    #информация о добавляемом сегменте лежит в JSONe, он может передаваться вместе с данными о файле
    #пока файл подчитывается из папки
    # println("я зашел")

    filename, filepath, datapath, param = parse_uri(req.target, srv)

    infoEvent = String(req.body)
    # println(infoEvent)
    #парсим команду
    port = srv.obj["IBox_port"]
    localIP = srv.obj["IBox_host"]
    #парсим команду
    segInRange = parseCommand(localIP, port, srv.obj,infoEvent)

    if isa(segInRange,StructArray)
        out = pack_vec(segInRange) |> base64encode
    else
        out = "Command was parsed"
    end

    res = out |> HTTP.Response |> addResponseHeader

    return res
end

"""
получение дерева классов QRS-комплекса в json-формате
работает ТОЛЬКО С ИСХОДНЫМИ ДАННЫМИ БОКСА - правки не подтягивает
"""
function getQRStree(srv::ServerState, req::HTTP.Request)

    filename, filepath, datapath, param = parse_uri(req.target, srv)

    port = srv.obj["IBox_port"]
    localIP = srv.obj["IBox_host"]

    #запрашиваем из Бокса данные для дерева
    r = HTTP.request("GET", "http://$localIP:$port/api/getData?dataName=QPoint&all")
    QPoint = reinterpret(Int32, base64decode(r.body)) |> collect

    r = HTTP.request("GET", "http://$localIP:$port/api/getData?dataName=ClassQRS&all")
    Class = reinterpret(Int32, base64decode(r.body)) |> collect

    r = HTTP.request("GET", "http://$localIP:$port/api/getData?dataName=SubClassQRS&all")
    SubClass = reinterpret(Int16, base64decode(r.body)) |> collect

    #строим дерево
    result = buildQRStree(QPoint, Class, SubClass)

    res = result |> HTTP.Response |> addResponseHeader

end

function undo!(srv::ServerState, req::HTTP.Request)
    port = srv.obj["IBox_port"]
    localIP = srv.obj["IBox_host"]

    undo!(srv.obj,localIP, port)
    @info srv.obj["history"]
    @info srv.obj["state"]
    out = "State "*string(srv.obj["state"])
    res = out|> HTTP.Response |> addResponseHeader

    return res
end

function redo!(srv::ServerState, req::HTTP.Request)
    port = srv.obj["IBox_port"]
    localIP = srv.obj["IBox_host"]

    redo!(srv.obj,localIP, port)

    out = "State "*string(srv.obj["state"])
    res = out|> HTTP.Response |> addResponseHeader

    return res
end



"""
Запуск сервера (в асинхронном режиме):

`server, task = start_server()`
`using Sockets
server, task = start_server(dir; localIP = Sockets.localhost, port = 8080)`

dir - локальная директория на сервере для работы с файлами, по умолчанию test\\files\n
localIP - локальный IP сервера, по умолчанию - IP машины в локальной сети, но можно указать просто "localhost"\n
port - порт, по умолчанию 8080
"""
start_server() = start_server("")
function start_server(dir::AbstractString; localIP = Sockets.getipaddr(), port = 8080)
    if isempty(dir)
        dir = joinpath(Base.@__DIR__, "..", "test", "files")
    end
    AllObj = Dict()
    AllObj["history"] = [] #тут храним действия над ВСЕМИ датагруппами подряд
    AllObj["state"] = 0
    AllObj["dataStorage"] = Dict{String,Any}()
    srv = ServerState(dir,AllObj)

    # define REST endpoints to dispatch to "service" functions
    #=const=# H5_ROUTER = HTTP.Router()

    # note the use of `*` to capture the path segment "variables"
    HTTP.@register(H5_ROUTER, "GET", "", handle)
    HTTP.@register(H5_ROUTER, "GET", "/api/runIBox", x->runIBox(srv, x))
    HTTP.@register(H5_ROUTER, "GET", "/api/Close", x->Close(srv, x))
    HTTP.@register(H5_ROUTER, "GET", "/api/getDataTree", x->redirectRequest(srv, x))
    HTTP.@register(H5_ROUTER, "GET", "/api/getData", x->redirectRequest(srv, x))
    HTTP.@register(H5_ROUTER, "GET", "/api/getStructData", x->redirectRequest(srv, x))
    HTTP.@register(H5_ROUTER, "GET", "/api/getTag", x->redirectRequest(srv, x))
    HTTP.@register(H5_ROUTER, "GET", "/api/getType", x->redirectRequest(srv, x))
    HTTP.@register(H5_ROUTER, "GET", "/api/getAttributes", x->redirectRequest(srv, x))
    HTTP.@register(H5_ROUTER, "POST", "/api/manualChange", x->manualChange(srv, x))
    HTTP.@register(H5_ROUTER, "GET", "/api/getFileInfo", x->redirectRequest(srv, x))
    HTTP.@register(H5_ROUTER, "GET", "/api/getQRStree", x->getQRStree(srv, x))
    HTTP.@register(H5_ROUTER, "GET", "/api/undo", x->undo!(srv, x))
    HTTP.@register(H5_ROUTER, "GET", "/api/redo", x->redo!(srv, x))


    # HTTP.@register(H5_ROUTER, "GET", "/api/getAttributes", x->getAttributes(srv, x))
    #
    server = Sockets.listen(localIP, port)
    HTTP.@register(H5_ROUTER, "GET", "/api/closeServer", req->(close(server); HTTP.Response("server closed")))

    task = @async HTTP.serve(H5_ROUTER, localIP, port; verbose = false, server = server)

    sleep(1) # пауза, чтобы вывод текста в консоль не перебивался потоком сервера

    @info "In browser:"
    @info "$localIP:$port/api/runIBox?res=oxy115829.dat&IBox_port=8888&IBox_path='C:/Temp/IBox/IBoxLauncher.exe'&IBox_host=127.0.0.1"
    @info "$localIP:$port/api/getDataTree"
    @info "$localIP:$port/api/getData?dataName=QPoint&index=0&from=0&to=10&count=100"

    @info "$localIP:$port/api/Close"
    @info "$localIP:$port/api/closeServer"

    server, task
end
