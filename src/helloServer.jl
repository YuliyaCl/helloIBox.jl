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
        @info filename

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

    out = "Тут тип загрузился бокс"

    args = `-config:IBTestWebApi -WebAPISrc[port=$port] -finalize -res:000`

    command = `$IBox_path $filepath $args`

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

    if haskey(srv.obj["dataStorage"],datapath) #был объект, значит были ручные правки - читаем из него
        out = "Объект имеется"
    else #объекта нет, значит читаем напрямую
        port = srv.obj["IBox_port"]
        localIP = srv.obj["IBox_host"]
        println("http://$localIP:$port$regstr")
        r = HTTP.request("GET", "http://$localIP:$port$regstr")
        out = r.body
    end

    res = out |> HTTP.Response |> addResponseHeader
end
function manualMark(srv::ServerState, req::HTTP.Request)
    filename, filepath, datapath, param = parse_uri(req.target, srv)
    infoEvent = String(req.body)
    #парсим команду
    segInRange = parseCommand(srv.obj,infoEvent)
    if isa(segInRange,StructArray)
        data = collect(zip(segInRange))
        out = base64encode(data)
    else
        out = "Command was parsed"
    end

    res = out|> HTTP.Response |> addResponseHeader

end

#бокс уже должен быть запущен! читаем данные из бокса по getData
function getData(srv::ServerState, req::HTTP.Request)
    filename, filepath, datapath, param = parse_uri(req.target, srv)

    @info filename, filepath, datapath, param
    port = srv.obj["IBox_port"]
    localIP = srv.obj["IBox_host"]

    data = getData(localIP,port,param)
    if !isempty(data)
        out = base64encode(collect(zip(data...)))
    else
        out = "null"
    end

    res = out |> HTTP.Response  |> addResponseHeader
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
    HTTP.@register(H5_ROUTER, "GET", "/api/getAttributes", x->redirectRequest(srv, x))


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
