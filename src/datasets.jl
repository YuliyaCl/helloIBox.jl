using Dates
struct LSB
    lsb # используется для расчетов
    amp # только для справки, 0 = не задано
    div # только для справки, 0 = не задано
end

#если просто  Int, то потом выдает ошибку в parseChAttr
LSB(amp, div) = LSB(amp / div, amp,div)
LSB(lsb::Float64) = LSB(lsb, 0, 0)

tounits(lsb::LSB, pt) = pt * lsb.lsb # из точки в физ. величину
topoints(lsb::LSB, x) = x / lsb.lsb # из физ. величины в точки (дробные)
tointpoints(lsb::LSB, x) = floor(Int, x / lsb.lsb) # из физ. величины в точки (целые)

struct PhysicalInfo # или иметь только один вариант и не париться?
    lsb::LSB
    units::String # названия ед. измерения
    maxval::Float64 # ?? нужны ли ??
    minval::Float64 # ??
end


struct FeatureInfo
    mode::String
    featureset #:: ? names, masks, checks
end

abstract type DataSet{T} end

mutable struct InMemory_data{T} #мб RingBuffer???
    ind #индексы, откуда прочитано
    data:: Vector{T}
    maxlen::Int64
    function InMemory_data{T}(maxlen::Int) where T
        new{T}(0:0,Vector{T}(undef,0), maxlen) #, 0)
    end
end

mutable struct PhysicalDataSet{T} <: DataSet{T} # а и б, только режим разный
    type::String # “signal” / “param”
    lsb::PhysicalInfo
    name::String
    datatype

    data
    data_IM::InMemory_data{T}
end

mutable struct IndexDataSet{T} <: DataSet{T}
    TG::TimeGrid
    name::String
    datatype

    data
    data_IM::InMemory_data{T}
end

mutable struct IntervalDataSet{T} <: DataSet{T}
    offsetdata #::IndexDataSet
    TG::TimeGrid
    name::String
    datatype

    data
    data_IM::InMemory_data{T}
end

mutable struct FeatureDataSet{T} <: DataSet{T}
    mask::Dict
    name::String
    datatype::DataType

    data
    data_IM:: InMemory_data{T}
end

#поиск информации о данных по их имени в дереве
function findnode(tree::Dict, dataname::String) where T
    Nnodes = length(tree["nodes"])
    for k=1:Nnodes
        node = tree["nodes"][k]
        if dataname==node["name"]
            return dataTree = node
        else
            dataTree = findnode(tree["nodes"][k]["nodes"], dataname)
            if ~isempty(dataTree)
                return dataTree
            end
        end
    end
    return []
end
function findnode(tree::Array, dataname::String) where T
    Nnodes = length(tree)
    for k=1:Nnodes
        node = tree[k]
        if dataname==node["name"]
            return dataTree = node
        else
            dataTree = findnode(tree[k]["nodes"],dataname)
            if ~isempty(dataTree)
                return dataTree
            end
        end
    end
    return []
end
#если атрибуты уже были считаны
function parseAttr(attr::Dict)
    #преобразованное время начала
    if haskey(attr, "TimeStart")
        if isa(attr["TimeStart"],Union{Int64,Float64})
            TimeStart = valToDate(attr["TimeStart"])
        else
            TimeStart = attr["TimeStart"]
        end
    else
        TimeStart = valToDate(0)
    end
    if haskey(attr, "Freq")
        Fs = Float64(attr["Freq"])
    else
        Fs = 1
    end
    #собираем временную сетку
    TG = TimeGrid(TimeStart, Fs)
    if haskey(attr, "amp")
        lsb = LSB(attr["amp"],attr["div"])
    else
        lsb = LSB(1,1)
    end
    if haskey(attr, "unit")
        units = attr["unit"]
    else
        units = ""
    end

    #minmax по умолчанию пока зануляем
    PhI = PhysicalInfo(lsb,units,0,0)

    return TG,PhI
end

function valToDate(datenum::Union{Int64,Float64})
    #преобразуем время из дней в DateTime
    dateMs = trunc(Int,datenum*24*60*60*1000) #врем в миллисекундах
    datenum = dateMs + Dates.value(DateTime(1900,12,30,00,00,00))
    dateTime = Dates.epochms2datetime(datenum)
end

#конструктор лямбда - функций для чтения
function construct_dsreadInRange(baseIP::IPv4,port::Union{String,Int64},groupname::String,dsname::String)
    fc = (from,to,count) -> getStructData(baseIP,port,groupname,dsname,"0",from,to,count)
    return fc
end
function construct_dsread(baseIP::IPv4,port::Union{String,Int64},dsname::String)
    fc = (from,to,count) -> getData(baseIP,port,dsname,"0",from,to,count)
    return fc
end

#создаем новый датасет - точнее открывем его и читаем атрибуты поля
function ds_new(baseIP::IPv4,port::Union{String,Int64},groupname::String,dsname::String, attr::Dict,TG = [], PhInfo = [])
    #если ничего не известно про атрибуты
    #информация о канале
    if isempty(TG)
        TG, PhInfo = parseAttr(attr)
    end
    dstype = attr["dstype"] #signal/param/index/interval/feature
    if dstype == "feature"
        mask = getMask(parseType(attr))
        if isempty(mask)
            #если не было маски, то называем тип по имени данных
            mask[dsname] = AllMask(UInt32(1),UInt32(1))
        end
    else
        mask = Dict()
    end

    dstype = attr["dstype"]
    #просто чтение по номеру в массиве
    ds_reader= construct_dsread(baseIP,port,dsname)

    if dstype == "signal"
        ds_readerInRange =  construct_dsread(baseIP,port,dsname)
    else
        ds_readerInRange =  construct_dsreadInRange(baseIP,port,groupname,dsname)
    end

    DS_obj= ds_new(baseIP,port,dsname,attr,ds_reader,ds_readerInRange,TG,PhInfo,mask)
    return DS_obj
end


#создаем объект набора данных
function ds_new(baseIP::IPv4,port::Union{String,Int64},dsname::String,attr::Dict,ds_reader,ds_readerInRange,TG::TimeGrid,PhInfo::PhysicalInfo,mask::Dict)
    dstype = attr["dstype"] #signal/param/index/interval/feature
    datatype = attr["datatype"]
    # datatype = getDataType(baseIP,port,dsname)
    if dstype == "interval"
        if haskey(attr,"offsetdata")
            OD = attr["offsetdata"]
        else
            OD = nothing
        end
        DS_obj = IntervalDataSet{datatype}(OD, TG, dsname, datatype, (ds_reader, ds_readerInRange),InMemory_data{datatype}(100))
    elseif dstype == "feature"
        DS_obj = FeatureDataSet{datatype}(mask,dsname, datatype, (ds_reader, ds_readerInRange),InMemory_data{datatype}(100))
    elseif dstype == "index"
        DS_obj = IndexDataSet{datatype}(TG, dsname, datatype, (ds_reader, ds_readerInRange),InMemory_data{datatype}(100))
    elseif dstype == "signal" || dstype == "param"
        DS_obj = PhysicalDataSet{datatype}(dstype,PhInfo,dsname, datatype, (ds_reader, ds_readerInRange),InMemory_data{datatype}(100))
    end
    DS_obj
end
