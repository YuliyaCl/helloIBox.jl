
using HTTP
using StructArrays

# T - Информация о времени (индексатор)
#     Freq - частота дискретизации
#     TimeStart - время старта
#     step - шаг (для прореженных рядов)
#     delay - задержка в отсчетах
#
# это TimeGrid из timeseries.jl


# A - Информация о физической величине (о канале)
#     Lsb | Amp, Div - коэффициенты пересчета (lsb = div / amp)
#     Unit - название физ. величины
#
struct LSB
    lsb # используется для расчетов
    Amp # только для справки, 0 = не задано
    Div # только для справки, 0 = не задано
end

#если просто  Int, то потом выдает ошибку в parseChAttr
LSB(Amp, Div) = LSB(Amp / Div, Amp, Div)
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

# F - Признак, форматы хранения:
#
#     а) бинарный массив,
#     mode = “bitarray”
#
#     б) категориальный массив,
#     mode = “category”
#     список: <имя признака> = <значение>
#
#     в) массив битовых масок
#     mode = “bitmask”
#     список: <имя признака> = <маска>
#
#

struct FeatureInfo
    mode::String
    featureset #:: ? names, masks, checks
end

"""
see features2.jl
"""

# ??? Category Array syntax !!!

# ??? BitVEctor feature name == data name


# D - Поле данных (массив):
#
#     а) сигнал / абсолютная величина (имеет физическую единицу, которая по умолчанию наследуется от канала)
#     dstype = “signal”
#     - A
#
#     б) параметр / относительная величина (не наследуется от физической величины канала, по умолчанию не определена)
#     dstype = “param”
#     - A
#
#     в) индекс (позиция, номер точки)
#     dstype = “index”
#     - T
#
#     г) интервал (ширина в точках)
#     dstype = “interval”
#     - offsetdata = <имя поля типа index для начал интервалов>
#     - T
#
#     д) признак
#     dstype = “feature”
#     - F
#

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
    data:: Vector{T}
    data_IM::InMemory_data{T}
end

mutable struct IndexDataSet{T} <: DataSet{T}
    TG::TimeGrid
    name::String
    data:: Vector{T}
    data_IM::InMemory_data{T}
end

mutable struct IntervalDataSet{T} <: DataSet{T}
    offsetdata #::IndexDataSet
    TG::TimeGrid
    name::String
    data:: Vector{T}
    data_IM::InMemory_data{T}
end

mutable struct FeatureDataSet{T} <: DataSet{T}
    mask::Dict
    name::String
    data:: Vector{T}
    data_IM:: InMemory_data{T}
end

#создаем новый датасет - точнее открывем его и читаем атрибуты поля
function ds_new(baseIP::IPv4,port::Union{String,Int64},nameGroup::String,nameDS::String)
    #если ничего не известно про атрибуты
    #информация о канале
    GrAttr = getAttr(baseIP,port,nameGroup)
    TG, PhInfo =  parseChAttr(GrAttr) #общая инфомрация о датасете
    #атрибуты данных
    attr = getAttr(baseIP,port,nameDS)

    dstype = attr["dstype"] #signal/param/index/interval/feature

    if dstype == "feature"
        mask = getMask(parseType(attr))
        if isempty(mask)
            #если не было маски, то называем тип по имени датагруппы
            mask[nameGroup] = AllMask(UInt32(1),UInt32(1))
        end
    else
        mask = Dict()
    end
    dataType = getDataType(baseIP,port,nameDS)
    DS_obj= ds_new(nameDS,attr,dataType,TG,PhInfo,mask)
    return DS_obj, TG, PhInfo, mask
end


function ds_new(nameDS::String,attr::Dict,dataType::DataType,TG::TimeGrid,PhInfo::PhysicalInfo,mask::Dict)
    dstype = attr["dstype"] #signal/param/index/interval/feature
    # elT = eltype(ds)
    if dstype == "interval"
        if haskey(attr,"offsetdata")
            OD = attr["offsetdata"]
        else
            OD = nothing
        end
        DS_obj = IntervalDataSet{elT}(OD, TG, nameDS,dataType,InMemory_data{dataType}(100))
    elseif dstype == "feature"
        DS_obj = FeatureDataSet{elT}(mask,nameDS,dataType,InMemory_data{dataType}(100))
    elseif dstype == "index"
        DS_obj = IndexDataSet{elT}(TG,nameDS,dataType,InMemory_data{dataType}(100))
    elseif dstype == "signal" || dstype == "param"
        DS_obj = PhysicalDataSet{elT}(dstype,PhInfo,nameDS,dataType,InMemory_data{dataType}(100))
    end
    DS_obj
end

using Dates
#разбираем базовые канальные атрибуты
#groupDataPath = "/Mark/ChName/GroupName/..."
function parseChAttr(filepath::String, groupDataPath::String)
    splitedDataPath = split(groupDataPath,"/")
    chDataPath = "/"*splitedDataPath[2]*"/"*splitedDataPath[3]
    attrCh = h5readattr(filepath,chDataPath)
    return parseChAttr(attrCh)
end

#если атрибуты уже были считаны
function parseChAttr(attrCh::Dict)
    #преобразованное время начала
    if haskey(attrCh, "TimeStart")
        TimeStart = valToDate(attrCh["TimeStart"])
    else
        TimeStart = valToDate(attrCh["StartTime"])
    end
    Fs = Float64(attrCh["Freq"])
    #собираем временную сетку
    TG = TimeGrid(TimeStart, Fs)
    if haskey(attrCh, "Amp")
        lsb = LSB(attrCh["Amp"],attrCh["Div"])
    elseif haskey(attrCh, "amp")
        lsb = LSB(attrCh["amp"],attrCh["div"])
    else
        lsb = LSB(1,1)
    end
    if haskey(attrCh, "Unit")
        units = attrCh["Unit"]
    else
        units = ""
    end

    #minmax по умолчанию пока зануляем
    PhI = PhysicalInfo(lsb,units,0,0)

    return TG,PhI
end

# G - Группа данных («папка»):
#     - T (у всех)
#
#     а) равномерно дискретный ряд
#     grouptype = “series”
#       - A
#
#     б) события
#     - имя поля индексации позиций
#     grouptype = “event”
#       - indexdata = <имя поля индексации позиций>
#
#     в) сегмент
#     - имя поля индексации начал
#     - имя поля индексации концов
#     grouptype = “segment”
#     - ibegdata = <имя поля индексации начал или ширин*>
#     - ienddata = <имя поля индексации концов или ширин*>
#     * Начала или ширины определяются по тому, какого типа эти поля. Если “index” - то абсолютные начала и концы, если “interval”, то ширины от какой-то опорной точки
#
#     г) канал (все данные, рассчитанные по приборному каналу)
#     grouptype = “channel”
#       - A (если есть)

function valToDate(datenum::Float64)
    #преобразуем время из дней в DateTime
    dateMs = trunc(Int,datenum*24*60*60*1000) #врем в миллисекундах
    datenum = dateMs + Dates.value(DateTime(1900,12,30,00,00,00))
    dateTime = Dates.epochms2datetime(datenum)
end


#запрос данных из датасета
function Base.getindex(DS::DataSet, ind::Int64)
    data = DS.data[ind]
    #ПОКА ВЫКЛЮЧАЮ КЕШИРОВАНИЕ
    # ind1 = DS.data_IM.ind
    # if !isempty(DS.data_IM.data) && ind<=ind1.stop && ind>=ind1.start#если новый диапазон внутри старого
    #     #переопределяем диапазон
    #     newind = ind - ind1.start +1
    #     data = DS.data_IM.data[newind]
    # else
    #     data = DS.data[ind]
    #     DS.data_IM.data = DS.data[ind]
    #     DS.data_IM.ind = ind:ind
    # end
    data
end

function Base.getindex(DS::DataSet, ind::UnitRange)
    data = DS.data[ind]
    #ПОКА ВЫКЛЮЧАЮ КЕШИРОВАНИЕ
    # ind1 = DS.data_IM.ind
    # if ind.start == 0 #иначе не пройдет
    #     ind = 1:ind.stop
    # end
    # if !isempty(DS.data_IM.data) && ind2Inind1(ind1,ind) #если новый диапазон внутри старого
    #     #переопределяем диапазон
    #     newstart = ind.start - ind1.start + 1
    #     newend = newstart + ind.stop - ind.start
    #     data = DS.data_IM.data[newstart:newend]
    # else
    #     data = DS.data[ind]
    #
    #     # DS.data_IM.data = data
    #     # DS.data_IM.ind = ind
    #     #можно чистить кеш через какое-то время
    #     #но фиг знает, норм ли будет, если будет много
    #     #запущенных процессов
    #     # @async clearDS!(DS,30)
    # end
    data
end
function Base.lastindex(DS::DataSet)
    ind = length(DS.data)
end

#ищем в массиве структур нужный датасет по имени
function getDS(DS_struct::StructArray, DSname::String)
    #вообще логично искать индексы соответствия типа
    # ind = contains(DS_struct.name,DSname)

    for ds in DS_struct
        if ds.name == DSname #нашли запрошенный датасет
            return ds.data
        end
    end
    println("DataSet is not found")
    return nothing
end
#вариант для вектора датасетов
function getDS(DS_vec::Vector{DataSet}, DSname::String)
    for ds in DS_vec
        if ds.name == DSname #нашли запрошенный датасет
            return ds
        end
    end
    println("DataSet is not found")
    return nothing
end

#запрос данных так, чтобы перезаписывались данные в "кеше"
function readData!(DS::DataSet,ind::UnitRange)
    DS.data_IM.data = DS.data[ind]
    DS.data_IM.ind = ind
end

#проверка пересечений диапазонов
function checkInd(ind1::UnitRange,ind2::UnitRange)
    isIntersect = (ind1.stop >= ind2.start && ind1.start <= ind2.stop) || (sign(ind1.start-ind2.start)!=sign(ind1.stop-ind2.stop))
end

#вложенность одного диапазона в другой
#чтобы если данные уже были считаны в более широком диапазоне,взять их оттуда
function ind2Inind1(ind1::UnitRange,ind2::UnitRange)
    ind2Inind1 = (sign(ind1.start-ind2.start)==-1 || ind1.start-ind2.start==0) && (sign(ind1.stop-ind2.stop) == 1 || ind1.stop-ind2.stop==0)
end

#очистка кеша датасета через какое-то время
function clearDS!(DS::DataSet, timeSec)
    sleep(timeSec)
    DS.data_IM.data = []
    DS.data_IM.ind = 1:1
    println("Clear cache for DS: "*DS.name)
end

function Base.length(DS::DataSet)
    len = length(DS.data)
end

function Base.size(DS::DataSet)
    len = size(DS.data)
end
#возвращает логические ind, которые соответствуют выбранным в строке типам
#filepath - путь к файлу (String)
#datapath - путь к датасету (String)
#param - параметры из строки запроса (Dict)
#ind - массив индексов для запрашиваемого датасета (Vector Int). Если пустой, то читается по всему датасету
function filtFeat(DS_obj::FeatureDataSet,fid,filepath,datapath,types::Vector{String}...)

    #читаем нужный датасет
    dataset = h5read(filepath,datapath*"/"*DS_obj.name)

    m = [mask[typ] for typ in types if haskey(mask, typ)] #берем только те признаки, которые указаны в параметрах
    alli = [checkType(t,m...) for t in dataset] #проверяем все типы на соответствие выбранным признакам
end
