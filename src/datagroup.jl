# abstract type DataGroup end

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
    filepath::String
    groupname::String

    TG:: TimeGrid
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

function dg_new(baseIP::IPv4,port::Union{String,Int64},filepath::String, datapath::String)

    attr = getAttr(baseIP,port, datapath)
    # TG,PhInfo = parseChAttr(filepath, datapath)

    #создаем пустую штуку для хранения истории
    URT = UndoRedoTool()
    #если это не группа(а вдруг датасет!)
    if !haskey(attr,"grouptype")
        return []
    else
        if attr["grouptype"]=="segment"
            # ibegdata = attr["ibegdata"]
            # ienddata = attr["ienddata"]
            # mask = getMask(parseType(attr))
            # if isempty(mask)
            #     #если не было маски, то называем тип по имени датагруппы
            #     grpname = split(datapath,"/")[end-1]
            #     mask[grpname] = AllMask(UInt32(1),UInt32(1))
            # end
            # DataSets, data = loadDataSets(fid,datapath)
            # dataStr = StructArray((name = DataSets, data = data))
            # if any(isa.(data,FeatureDataSet))
            #     featureName = DataSets[isa.(data,FeatureDataSet)][1]
            # else
            #     featureName = "none"
            # end
            # DG_obj = SegmentDataGroup(filepath,datapath,fid,TG,ibegdata,ienddata,featureName,mask,dataStr,[],URT)
        elseif attr["grouptype"]=="series"

            DataSets, data = loadDataSets(fid,datapath)
            dataStr = StructArray((name = DataSets, data = data))

            DG_obj = SeriesDataGroup(filepath, datapath, fid, TG, PhInfo, dataStr,[], URT)
        elseif attr["grouptype"]=="event"
            index = attr["indexdata"]

            DataSets, data = loadDataSets(fid,datapath)
            dataStr = StructArray((name = DataSets, data = data))

            DG_obj = EventDataGroup(filepath, datapath, fid, TG, index, dataStr,[], URT)

        elseif attr["grouptype"]=="channel"

            DataSets, data = loadDataSets(fid,datapath)
            dataStr = StructArray((name = DataSets, data = data))
            DG_obj = ChannelDataGroup(filepath, datapath, fid, TG, PhInfo, dataStr,[], URT)

        else #непонятные данные
            DataSets, data = loadDataSets(fid,datapath)
            dataStr = StructArray((name = DataSets, data = data))
            DG_obj = UnknownDataGroup(filepath, datapath, fid, attr, dataStr, [], URT)

        end
    end
    DG_obj.UndoRedo.sourse = DG_obj
    return DG_obj
end

#создаем датасеты на группу
function loadDataSets(baseIP::IPv4,port::Union{String,Int64},datapath::String)

    r = HTTP.request("GET", "http://$baseIP:$port/api/getDataTree")
    tree = JSON.parse(String(r.body))[1]

    g = g_open(fid, datapath)
    dataNames = names(g)  #какие датасеты содержит группа
    flLoadDS = typeof(fid[datapath*dataNames[1]*"/"])==HDF5Dataset


    if !flLoadDS #а вдруг это группа
        data = Vector{DataGroup}(undef,length(dataNames))
        i = 1
        for gr in dataNames
             data[i] = dg_new(fid, datapath*gr*"/")
             i+=1
         end
    else
        data = Vector{DataSet}(undef,length(dataNames))
        #DS_obj, fid, TG, PhInfo, mask = ds_new(fid, datapath,  DataSets[1])
        #data[1] = DS_obj
        i = 1
        for nameDS in dataNames #[2:end]
            DS_obj, fid, TG, PhInfo, mask = ds_new(fid, datapath,  nameDS)
                #DS_obj = ds_new(fid, datapath, nameDS, TG, PhInfo, mask)
            data[i] = DS_obj
            i+=1
        end
    end

    return dataNames, data
end
