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

function dg_new(baseIP::IPv4,port::Union{String,Int64},groupName::String)

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
    DG.result = StructArray((convert.(DG.data[DG.ibegdata].datatype,result.ibeg), convert.(DG.data[DG.ienddata].datatype,iend), result.type), names = (Symbol(DG.ibegdata),Symbol(DG.ienddata),Symbol(DG.typename)))
end

#изменение типа сегментов, попавших в диапазон от-до
function changeType!(DG::SegmentDataGroup,from::Int64,to::Int64, mode::String,type_names::Union{String,Vector{String}},mask::Dict)
    if DG.UndoRedo.state==0 #&& (!haskey(URT.result["ibeg"]) || isempty(URT.result["ibeg"]))
        #если ничего не делалось над объектом, то читаем данные из источника
        #если ничего не делалось над объектом, то читаем данные из источника
        ibeg, iend, type, isW = getSegBegsType(DG)
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
        ibeg = list[1]
        type = list[3]
    end
    #определяем попавшие в диапазон сегменты
    segRange = searchinrange(ibeg,iend,from,to)
    if mode == "delete"
        #прям удаляем сегменты, попавшие под выделение
        deleteat!(ibeg,segRange)
        deleteat!(iend,segRange)
        deleteat!(type,segRange)
    elseif mode=="setbit"
        #присваеваем новый тип
        new_types = setbit(mask,type[segRange],type_names)
        type[segRange] .= new_types
    elseif mode=="rewrite"
        new_types = detIntType(DG.mask,type_names)
        type[segRange] .= new_types
    end
    if isW
        iend = iend - ibeg
    end
    #записываем новые сегменты
    DG.result = StructArray((convert.(DG.data[DG.ibegdata].datatype,ibeg), convert.(DG.data[DG.ibegdata].datatype,iend), type), names = (Symbol(DG.ibegdata),Symbol(DG.ienddata),Symbol(DG.typename)))
end

#обработка команды-правки пользователя
#AllObj - набор датагрупп в памяти
#command - прочитанный в String JSON-file
#flUR - флаг Undo-Redo , если true, то история не перетирается
function parseCommand(baseIP::IPv4,port::Union{String,Int64}, AllObj::Dict,command::String,flUR = 0)
    #разбор JSON-a
    #судя по докам, он умеет парсить только в словарь
    #на сервере уже разбирали файл-команду
    manualEvent = JSON.parse(command)

    #пока считаем, что имя группы лежит в chName
    gp_name = manualEvent["chName"]
    comandID = manualEvent["command"]["id"] #определяем, какую команду делаем с сегментом
    #в sessionID идентификатор события
    if haskey(manualEvent,"sessionID")
        sessionID = manualEvent["sessionID"]
    else
        sessionID = "12345"
    end
    #ТУТ НАДО НАЙТИ ОБЪЕКТ, КОТОРЫЙ СООТВЕТСТВУЕТ ДАННЫМ, КОТОРЫЕ ПРАВИМ
    if ~isempty(AllObj["dataStorage"]) && haskey(AllObj["dataStorage"],gp_name)
        DG = AllObj["dataStorage"][gp_name]
    else
        DG = dg_new(baseIP,port,gp_name)
        @info AllObj["dataStorage"]
        AllObj["dataStorage"][gp_name] = DG
        #тут можно использовать targetData
    end

    # filePath = collect(splitpath(DG.filepath))

    #Это бы надо куда-то снаружи, но ладно. Мы ж независимы..

    filePath =  sessionID*"_history.json"
    historyPath = sessionID*"_history.json"
    # @info historyPath
    if comandID == "ADD_SEGMENT"
        #границы добавляемого фрагмента
        ibeg = convert.(Int,manualEvent["command"]["args"]["ibeg"])
        iend = convert.(Int,manualEvent["command"]["args"]["iend"])
        type = convert.(String,manualEvent["command"]["args"]["type"])
        if type == "+"
            type = string(keys(DG.mask))[3:end-2]
        end
        if haskey(manualEvent["command"]["args"],"mode")
            mode = manualEvent["command"]["args"]["mode"]
        else
            mode = "rewrite"
        end
        typeNum = detIntType(DG.mask,type) #преобразуем тип в число
        type = Vector{Int}(undef,length(ibeg)) #если несколько
        type[1:end] .= typeNum

        if !isa(ibeg,Vector) #если было одно значение только, то его в вектор надо
            ibeg = [ibeg]
            iend = [iend]
        end

        newSeg = StructArray(ibeg = ibeg, iend = iend, type = type)
        #addSeg!(DG,newSeg,"rewrite",commandToString(manualEvent["command"]))
        addSeg!(DG,newSeg,mode)

    elseif comandID == "CHANGE_TYPE" || comandID == "DELETE_SEGMENT"
        from = manualEvent["command"]["args"]["ibeg"]
        to = manualEvent["command"]["args"]["iend"]
        newType = manualEvent["command"]["args"]["type"]
        if comandID == "CHANGE_TYPE"
            mode = manualEvent["command"]["args"]["mode"]
        else
            mode = "delete"
            newType = Vector{String}()
        end
        changeType!(DG,from,to,mode,newType,DG.mask) #type - вектор String c именами
    else
        println("Unknown command")
    end
    #обновляем состояние,наращиваем историю
    #если стейт и количество объектов в истории совпадают - то все норм
    if flUR==0
        #это не  undo-redo - пришла новая правка
        if DG.UndoRedo.state==size(DG.UndoRedo.history,1)
            DG.UndoRedo.state+=1
            push!(DG.UndoRedo.history,command)

            push!(AllObj["history"],command)
            AllObj["state"] += 1
        elseif DG.UndoRedo.state<=size(DG.UndoRedo.history,1)
            #если была новая правка после undo, То все после в истории надо перетереть
            deleteat!(DG.UndoRedo.history,DG.UndoRedo.state+1:size(DG.UndoRedo.history,1))
            DG.UndoRedo.state+=1
            push!(DG.UndoRedo.history,command)

            deleteat!(AllObj["history"],AllObj["state"]+1:size(AllObj["history"],1))
            push!(AllObj["history"],command)
            AllObj["state"] += 1
        end
        # пишем
        writeManualMark(command, historyPath)

    elseif flUR == 1
        #1 - значит redo
        # пишем команду
        writeManualMark(command, historyPath)

    elseif flUR == -1
        #-1 - значит undo и надо удалить последнюю строку из файла
        #ничего не делаем
        deleteLastCommand(historyPath)
    end
    #если были заданы границы, то выдаем сегменты в них
    if haskey(manualEvent,"fromto")
        segInRange = getSegInRange(DG, manualEvent["fromto"][1],manualEvent["fromto"][2])
        return segInRange
    else
        return AllObj
    end

end

function findSegDS(DG::SegmentDataGroup,from::Union{Int32,Int64},to::Union{Int32,Int64},features="")
    if !isempty(DG.result)
        iendDS =  DG.data[DG.ienddata]
        isW = isa(iendDS, IntervalDataSet) #ширина ли это

        resultOld = DG.result
        list = getfield(resultOld, :fieldarrays) #тк в резалте другие имена, пересобираем в стандартные
        if isW
            iend = list[1] + list[2]
        else
            iend = list[2]
        end
        ibeg = list[1]
        type = list[3]

        segs = DG.result
    else
        ibeg, iend, type, isW = getSegBegsType(DG)
        if iW
            iendW = iend - ibeg
        else
            iendW = iend
        end
        segs = StructArray(ibeg = ibeg,iend = iendW,type = type)
    end
    return segs,ibeg,iend
end
#запрос сегментов в диапазоне - нужно для отправки клиенту для отрисовки
#в features добавить фильтр по типу
function getSegInRange(DG::SegmentDataGroup,from::Int64,to::Int64,features="")

    segs,ibeg,iend = findSegDS(DG,from,to)
    range = searchinrange(ibeg,iend,from,to)

    SIR = segs[range]
    """
    добавить фильтр по типам из features
    """
    #тут надо наверное делать json или еще что-то
    return SIR
end

function getStructData(DG::Union{SegmentDataGroup,EventDataGroup},from,to,dsTake="all")
    if isa(DG,SegmentDataGroup)
        if !isempty(DG.result)
            segs,ibeg,iend = findSegDS(DG,from,to)
            range = searchinrange(ibeg,iend,from,to)
            data = getData(DG,range.start,range.stop,dsTake)
        end
    end
end
#запрос данных из датагрупп
function getData(DG::Union{SegmentDataGroup,EventDataGroup},from,to,dsTake="all")
    ind = Int32(from):Int32(to)
    data = DG.result
    allInRes = true
    if dsTake != "all"
        if ~isa(dsTake,Vector)
            dsTake = [dsTake]
        end
        for dsT in dsTake
            #если хотим что-то из нередактируемых данных
            allInRes = allInRes && any(Symbol(dsT).==propertynames(DG.result)) && dsT!="original"
        end
    end
    if DG.UndoRedo.state>0 && !isempty(DG.result) && allInRes
        allDS = DG.result
        data = Vector{Any}()
        list = getfield(allDS, :fieldarrays)
        if dsTake=="all"
            for i = 1:length(propertynames(allDS))
                addData = list[i][ind]
                push!(data,addData)
            end
        else
            i=1
            for key in dsTake
                fi = findall(x-> x== Symbol(key), propertynames(allDS))
                if !isempty(fi) #запрашеваемое поле найдено
                    addData = convert.(DG.data[key].datatype,list[fi[1]][ind])
                    # addData = list[fi[1]][ind]
                    push!(data,addData)
                end
                i+=1
            end
            if length(dsTake) == 1
                data = data[1]
            end
        end
        return data
    else
        println("Даные были изменены, пока доступа к ним нет")
        return []
        # allDS = DG.data.data
        # DSs = [[DG.data.data[i].data] for i = 1:length(DG.data)]
        # allDS = StructArray((DSs...,), names = (Symbol.(DG.data.name)...,))
    end

end
