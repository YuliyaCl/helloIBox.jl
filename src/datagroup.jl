include("timeseries.jl")
include("datasets.jl")
abstract type DataGroup end

mutable struct SeriesDataGroup <:DataGroup #signal равномерно дискретный ряд
    filepath::String
    groupname::String

    TG::TimeGrid
    A::PhysicalInfo
    data
    result #итоговый результат всех правок над данными
    UndoRedo::UndoRedoTool
end

mutable struct EventDataGroup <:DataGroup #события
    filepath::String
    groupname::String

    TG::TimeGrid
    indexdata::String
    data
    result #итоговый результат всех правок над данными
    UndoRedo::UndoRedoTool
end

mutable struct ChannelDataGroup <:DataGroup # канал (все данные, рассчитанные по приборному каналу)
    filepath::String
    groupname::String

    TG::TimeGrid
    A::PhysicalInfo
    data #::StructArray
    result #итоговый результат всех правок над данными
    UndoRedo::UndoRedoTool
end

mutable struct SegmentDataGroup <:DataGroup #сегмент
    # filepath::String
    groupname::String

    TG::TimeGrid
    ibegdata:: String
    ienddata:: String
    typename:: String
    mask:: Dict

    data
    result #итоговый результат всех правок над данными
    UndoRedo:: UndoRedoTool

end

mutable struct UnknownDataGroup <:DataGroup #сегмент
    filepath::String
    groupname::String

    attr::TimeGrid

    data
    result #итоговый результат всех правок над данными
    UndoRedo::UndoRedoTool

end

function dg_new(baseIP::IPv4,port::Union{String,Int64},groupName::String, dataName::String)

    r = HTTP.request("GET", "http://$baseIP:$port/api/getDataTree")
    tree = JSON.parse(String(r.body))[1]
    node =  findnode(tree, groupName) #запрос группы
    attr = node["attrs"]

    #пока берем так. но надо бы из группы данных
    r = HTTP.request("GET", "http://$baseIP:$port/api/getData?dataName=Freq&index=0&from=0&count=1")
    Freq = reinterpret(Int32, base64decode(r.body)) |> collect
    r = HTTP.request("GET", "http://$baseIP:$port/api/getData?dataName=StartTime&index=0&from=0&count=1")
    StartTime = reinterpret(Int32, base64decode(r.body)) |> collect

    attr["Freq"] = Freq[1]
    attr["StartTime"] = StartTime[1]
    #определяем временную сетку. хз зачем, правда
    TG,PhInfo = parseAttr(attr)

    #создаем пустую штуку для хранения истории
    URT = UndoRedoTool()
    #если это не группа(а вдруг датасет!)
    if !haskey(attr,"grouptype")
        return []
    else
        if haskey(attr, "grouptype") && attr["grouptype"]=="segment"
            ibegdata = attr["ibegdata"]
            ienddata = attr["ienddata"]
            if haskey(attr,"typedata")
                featureName = attr["typedata"]
                loadDsNames = [ibegdata, ienddata, featureName]
            else
                featureName = "none"
                loadDsNames = [ibegdata, ienddata]
            end
            mask = getMask(parseType(attr))
            if isempty(mask)
                #если не было маски, то называем тип по имени датагруппы
                mask[groupName] = AllMask(UInt32(1),UInt32(1))
            end

            DS = Dict{String,Any}()
            for ds in loadDsNames
                node =  findnode(tree, ds) #запрос группы
                attrds = node["attrs"]
                attrds["datatype"] = eval(Symbol(node["type"]))
                attrds["Freq"] = Freq[1]
                attrds["StartTime"] = StartTime[1]
                DS[ds] = ds_new(baseIP,port,groupName,ds, attrds)
            end
            # DataSets, data = loadDataSets(fid,datapath)
            # dataStr = StructArray((name = DataSets, data = data))
            # if any(isa.(data,FeatureDataSet))
            #     featureName = DataSets[isa.(data,FeatureDataSet)][1]
            # else
            #     featureName = "none"
            # end
             DG_obj = SegmentDataGroup(groupName,TG,ibegdata,ienddata,featureName,mask,DS,[],URT)
        # elseif attr["grouptype"]=="series"
        #
        #     DataSets, data = loadDataSets(fid,datapath)
        #     dataStr = StructArray((name = DataSets, data = data))
        #
        #     DG_obj = SeriesDataGroup(filepath, datapath, fid, TG, PhInfo, dataStr,[], URT)
        # elseif attr["grouptype"]=="event"
        #     index = attr["indexdata"]
        #
        #     DataSets, data = loadDataSets(fid,datapath)
        #     dataStr = StructArray((name = DataSets, data = data))
        #
        #     DG_obj = EventDataGroup(filepath, datapath, fid, TG, index, dataStr,[], URT)
        #
        # elseif attr["grouptype"]=="channel"
        #
        #     DataSets, data = loadDataSets(fid,datapath)
        #     dataStr = StructArray((name = DataSets, data = data))
        #     DG_obj = ChannelDataGroup(filepath, datapath, fid, TG, PhInfo, dataStr,[], URT)

        else #непонятные данные
            # DataSets, data = loadDataSets(fid,datapath)
            # dataStr = StructArray((name = DataSets, data = data))
            # DG_obj = UnknownDataGroup(filepath, datapath, fid, attr, dataStr, [], URT)
            DG_obj = []
        end
    end
    DG_obj.UndoRedo.sourse = DG_obj
    return DG_obj
end

#смотрим, исходные ширины это сегменты с началом-концом или шириной
function getSegBegsType(DG::SegmentDataGroup)
    #!!!! исправить длину
    ibeg =  DG.data[DG.ibegdata].data[1]("0","","100")
    iendDS = DG.data[DG.ienddata]
    typename = DG.typename

    isW = isa(iendDS, IntervalDataSet) #ширина ли это
    if isW
        iend = ibeg + Int32.(iendDS.data[1]("0","","100"))
    else
        iend = iendDS.data[1]("0","","100")
    end
    if occursin(typename,"none") #none там, где нет данных типа
        type = ones(Int64,size(ibeg))
    else
        type =DG.data[typename].data[1]("0","","100")
    end

    ibeg, iend, type, isW
end
#добавление нового сегмента
#command тут не обрабатывается, только пишется в историю правок датагруппы
function addSeg!(DG::SegmentDataGroup,newSeg::StructArray, mode::String)

    if isempty(DG.result) || DG.UndoRedo.state==0 #&& (!haskey(URT.result["ibeg"]) || isempty(URT.result["ibeg"]))
        #если ничего не делалось над объектом, то читаем данные из источника
        ibeg, iend, type, isW = getSegBegsType(DG)
        oldSeg = StructArray(ibeg = ibeg, iend = iend, type = type)
    else
        #если были правки раньше
        iendDS =  DG.data[DG.ienddata]
        isW = isa(iendDS, IntervalDataSet) #ширина ли это

        resultOld = DG.result
        list = getfield(resultOld, :fieldarrays) #тк в резалте другие имена, пересобираем в стандартные
        if isW
            iend = list[1] + list[2]
        else
            iend = list[2]
        end
        oldSeg = StructArray((list[1], iend, list[3]), names = (Symbol("ibeg"),Symbol("iend"),Symbol("type")))
    end
    result = add_seg(oldSeg,newSeg,mode)
    if isW
        iend = result.iend - result.ibeg
    else
        iend = result.iend
    end
    DG.result = StructArray((result.ibeg, iend, result.type), names = (Symbol(DG.ibegdata),Symbol(DG.ienddata),Symbol(DG.typename)))
end
