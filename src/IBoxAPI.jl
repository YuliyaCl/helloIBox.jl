#запрос данных из бокса
function getData(baseIP::IPv4,port::Union{String,Int64},param::Dict)
#baseURI = $localIP:$port
    strParams = []
    for key in keys(param)
        push!(strParams,String(key)*"="*param[key]*"&")
    end

    strParams = join(strParams)

    if !haskey(param,"to") && !haskey(param,"count") #если не было указано конца, то читаем всё
        strParams = strParams*"all&"
    end

    if !haskey(param,"from")
        strParams = strParams*"from=0&"
    end
    # println("http://$baseIP:$port/apibox/getData?$strParams")
    res = HTTP.request("GET", "http://$baseIP:$port/api/getData?$strParams")
    data = res.body
    index = param["index"]

    dataType = getDataType(baseIP,port,param["dataName"],param["index"]) #узнаем тип данных
    convertedData = reinterpret(dataType, base64decode(data)) |> collect
    # @info convertedData
    return convertedData
end

#запрос данных из в интервале как бы
function getStructData(baseIP::IPv4,port::Union{String,Int64},dataName::String, fields::String,index="0",from="0",to="",count="")
    param = Dict()
    param["dataName"] = dataName
    param["index"] = index
    param["from"] = from
    param["to"] = to
    param["count"] = count
    param["fields"] = fields

    data = getStructData(baseIP, port, param)
    return data
end
function getStructData(baseIP::IPv4,port::Union{String,Int64},param::Dict)
#baseURI = $localIP:$port
    strParams = []
    for key in keys(param)
        push!(strParams,String(key)*"="*param[key]*"&")
    end

    strParams = join(strParams)

    if !haskey(param,"to") && !haskey(param,"count")
        strParams = strParams*"all&"
    end

    if !haskey(param,"from")
        strParams = strParams*"from=0&"
    end

    println("http://$baseIP:$port/api/getStructData?$strParams")
    res = HTTP.request("GET", "http://$baseIP:$port/api/getStructData?$strParams")
    data = res.body
    # @info data
    fields = param["fields"]
    allFields = split(fields,",")
    alldataType = [] #собираем типы данных, чтобы работать с ними
    for f in allFields
        push!(alldataType, getDataType(baseIP,port,string(f))) #узнаем тип данных
    end

    convertedData = reinterpret(alldataType[1], base64decode(data)) |> collect
    @info alldataType
    return convertedData
end

function getData(baseIP::IPv4,port::Union{String,Int64},dataName::String,index=0,from=0,to=[],count=[])

    addToRequest = ""
    if isempty(to) && isempty(count) #если не было указано конца, то читаем всё
        addToRequest = "&all"
    else
        if ~isempty(to)
            addToRequest = addToRequest*"&to=$to"
        end
        if ~isempty(count)
            addToRequest = addToRequest*"&count=$count"
        end
        if ~isempty(from)
            addToRequest = addToRequest*"&from=$from"
        end
    end
    res = HTTP.request("GET", "http://$baseIP:$port/api/getData?dataName=$dataName&index=$index$addToRequest")
    data = res.body

    dataType = getDataType(baseIP,port,dataName, index) #узнаем тип данных
    convertedData = reinterpret(dataType, base64decode(data)) |> collect
    return convertedData
end

function getCountDataInInterval(baseIP::IPv4,port::Union{String,Int64}, param::Dict)
    if haskey(param,"index")
        ind = param["index"]
    else
        ind = 0
    end

    if haskey(param,"from")
        from = param["from"]
    else
        from = 0
    end

    if haskey(param,"to")
        to = param["to"]
    else
        to = []
    end
    if haskey(param,"count")
        count = param["count"]
    else
        count = []
    end

    countData = getCountDataInInterval(baseIP,port,param["dataName"],ind,from,to,count)
end
#определяем, сколько точек попало в заданный диапазон
function getCountDataInInterval(baseIP::IPv4,port::Union{String,Int64},dataName::String,index=0,from=0,to=[],count=[])
    addToRequest = ""
    if isempty(to) && isempty(count) #если не было указано конца, то читаем всё
        addToRequest = "&all"
    else
        if ~isempty(to)
            addToRequest = addToRequest*"&to=$to"
        end
        if ~isempty(count)
            addToRequest = addToRequest*"&count=$count"
        end
    end
    res = HTTP.request("GET", "http://$baseIP:$port/apibox/getCountDataInInterval?dataName=$dataName&index=$index$addToRequest")
    data = String(res.body)
    count = parse(Int32, data)
    if count<0 count=0 end #если данные не найдены, то возвращает 0

    # @info data
    # convertedData = reinterpret(Int32, base64decode(data)) |> collect
    return count

end
#запрос атрибутов из бокса
#преобразуются в словарь, так как записаны в формате JSON
function getAttr(baseIP::IPv4,port::Union{String,Int64},dataName::String)
#dataName = /Mark/Reo_0/breathsegpar
    res = HTTP.request("GET", "http://$baseIP:$port/api/getAttributes?dataName=$dataName")
    data = String(res.body)
    attrs = JSON.parse(data)
    return attrs["attrs"]
end

#получение имени данного
function getTag(baseIP::IPv4,port::Union{String,Int64},dataName::String,index=0)
    # println("http://$baseIP:$port/apibox/getData?getTag=$dataName&index=$index")
    res = HTTP.request("GET", "http://$baseIP:$port/apibox/getTag?dataName=$dataName&index=$index")
    tag = String(res.body)

    return  tag
end

#получение количества детей
function getChildsCount(baseIP::IPv4,port::Union{String,Int64},dataName::String,index::Union{String,Int64})
    # println("http://$baseIP:$port/apibox/getData?getTag=$dataName&index=$index")
    res = HTTP.request("GET", "http://$baseIP:$port/apibox/getChildsCount?getTag=$dataName&index=$index")
    count = String(res.body)

    return  count
end

#структура файла
function getDataTree(localIP::IPv4,port::Union{String,Int64})
    res = HTTP.request("GET", "http://$localIP:$port/api/getDataTree")
    # @info res
    out = String(res.body)
    parse(out)
    return tree
end

#определение типа данных на основании EntityInfo
function getDataType(baseIP::IPv4,port::Union{String,Int64},dataName::String,index=0)
    #проверяем, не составное ли имя
    dnparts = split(dataName,"_")
    if length(dnparts)>1
        index = dnparts[2]
        dataName =  dnparts[1]
    end
    res = HTTP.request("GET", "http://$baseIP:$port/apibox/getEntityInfo?dataName=$dataName&index=$index")
    info = res.body
    info = String(info)
    if occursin("type: float",info)
        dataType = Float32
    elseif occursin("type: long",info)
        dataType = Int32
    elseif occursin("type: BYTE",info)
        dataType = UInt8
    elseif occursin("type: WORD",info)
        dataType = UInt16
    elseif occursin("type: char",info)
        dataType = Int8
    elseif occursin("type: Time",info)
        dataType = DateTime
    elseif occursin("type: bin16",info)
        dataType = BitArray #но тут я не уверена
    elseif occursin("type: object",info)
        dataType = []
    else
        println("Неизвестный тип "*info)
    end
    return dataType
end
