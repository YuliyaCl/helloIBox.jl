#запрос данных из бокса
function getData(baseIP::IPv4,port::Union{String,Int64},param::Dict)
#baseURI = $localIP:$port
    strParams = []
    for key in keys(param)
        push!(strParams,String(key)*"="*param[key]*"&")
    end
    strParams = join(strParams)
    println("http://$baseIP:$port/apibox/getData?$strParams")
    res = HTTP.request("GET", "http://$baseIP:$port/apibox/getData?$strParams")
    data = res.body
    index = param["index"]

    dataType = getDataType(baseIP,port,param["dataName"],param["index"]) #узнаем тип данных
    convertedData = reinterpret(dataType, base64decode(data)) |> collect

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
    end
    res = HTTP.request("GET", "http://$baseIP:$port/apibox/getData?dataName=$dataName&index=$index$addToRequest")
    data = res.body

    dataType = getDataType(baseIP,port,dataName, index) #узнаем тип данных
    convertedData = reinterpret(dataType, base64decode(data)) |> collect
    return convertedData
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
    data = res.body
    @info data
    convertedData = reinterpret(Int32, base64decode(data)) |> collect
    return convertedData

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
        dataType = Time
    elseif occursin("type: bin16",info)
        dataType = BitArray #но тут я не уверена
    elseif occursin("type: object",info)
        dataType = []
    else
        println("Неизвестный тип "*info)
    end
    return dataType
end
