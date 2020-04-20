

#возвращает логические ind, которые соответствуют выбранным в строке типам
#datapath - путь к датасету (String)
function filtFeat(fid::HDF5File,datapath::String,dataName::String,types::Vector{String})
    DS_obj,fid,TG,PhInfo,mask = ds_new(fid,datapath,dataName)
    #берем данные
    dataset = DS_obj[1:end]
    #читаем нужный датасет
    #dataset = h5read(filepath,datapath*"/"*DS_obj.name)

    m = [mask[typ] for typ in types if haskey(mask, typ)] #берем только те признаки, которые указаны в параметрах
    alli = [checkType(t,m...) for t in dataset] #проверяем все типы на соответствие выбранным признакам
end

function filtFeat(DG::DataGroup,param,ind = [])
    #берем данные по полю type, если оно есть
    if any(DG.data.name.=="type")
        DS = getDS(DG,"type")
        if !isempty(ind)
            dataset = DS[ind]
        else
            dataset = DS[1:end]
        end
        if isa(DS, FeatureDataSet)
            mask = DS.mask
        else
            indType = DG.data.name.=="type"
            if any(indType)
                mask = DG.data.data[indType][1].mask
            else
                mask = DG.mask
            end
        end

        typesMask = haskey(param, "feature") ? split(param["feature"], ',') : Vector{String}()
        m = [mask[typ] for typ in typesMask if haskey(mask, typ)] #берем только те признаки, которые указаны в параметрах
        # @info mask
        alli = [checkType(t,m...) for t in dataset] #проверяем все типы на соответствие выбранным признакам
    else
        #берем все элементы (как для badseg, например, где нет типа)
        alli = Vector{Bool}(undef,L)
        if !isempty(ind)
            L = stop-start+1
        else
            L = length(DG)
        end
        alli.=true
    end
end

#работа с выбором данных из группы
function getDataFields(DG::DataGroup, fields, ind, r_ind)
    data = Vector{Any}()
    if isempty(fields)
        fields = "all"
    end

    data = DG[ind, fields]
    if !isa(data,Vector{Any})
        data = [data[r_ind]]
    else
        N = size(data)[1]
        data = [data[i][r_ind] for i=1:N]
    end
    out = collect(zip(data...))
end

#все фильтры в одной функции
function getFiltInd(DG::DataGroup,param,ind)
    if !isempty(param) && haskey(param,"feature")
        iFiltFeat = filtFeat(DG,param,ind)
    else
        iFiltFeat = ones(Bool, length(ind))
    end

    if !isempty(param) && haskey(param,"compfields")
        iFiltComp = filtCompField(DG,param,ind)
    else
        iFiltComp = ones(Bool, length(ind))
    end

    r_ind = iFiltFeat .& iFiltComp
    return r_ind
end

#берем индексы из датагруппы
function filtInd(DG::SegmentDataGroup,from,to)
    ibegs = getDS(DG,DG.ibegdata)[1:end]
    iends = getDS(DG,DG.ienddata)[1:end]

    from = from==nothing ? ibegs[1] : from
    to = to==nothing ? iends[end] : to

    i1, i2 = findwithin(ibegs, iends, from+1, to)
    if (i1 < 0 || i2 < 0)
        return 1:0
    end
    return i1:i2
end

#для событий ищем по полю индексации
function filtInd(DG::EventDataGroup,from,to)
    inds =  getDS(DG,DG.indexdata)[1:end]

    from = from==nothing ? inds[1] : from
    to = to==nothing ? inds[end] : to
    i1, i2 = findwithin(inds, from, to)
    #i1, i2 = findwithin(inds, from+1, to) #было +1, хз почему
    if (i1 < 0 || i2 < 0)
        return 1:0
    end
    return i1:i2
end

#просто индексы для сигнала или другого равномерного ряда
function filtInd(DG::DataGroup,from,to)
    l = length(DG)
    from = from==nothing ? 0 : from
    to = to==nothing ? l : to
    inds = Array{Int32,1}(1:l)
    i1, i2 = findwithin(inds, from, to)
    #i1, i2 = findwithin(inds, from+1, to) #было +1, хз почему
    if (i1 < 0 || i2 < 0)
        return 1:0
    end
    return i1:i2
end


#получение типа int по набору признаков
function detIntType(mask::Dict,types::String)
    type = mask[types].featureMask & mask[types].valueMask
    typeint = Int(type)
end

#возвращает по типу имена входящих в него признаков
function detStringType(mask::Dict,type::Int)
    fields = mask.keys[mask.slots .!= 0]
    r = [checkType(type,mask[f]) for f in fields]
    fields[r]
end

#устанавливает в types биты, соответствующие bitName
function setbit(mask::Dict,types::Vector{Any},bitName::Vector{String})
    m = [mask[btN] for btN in bitName if haskey(mask, btN)]
    L = length(types)
    newTypes = Array{Int,1}()
    for i = 1:L
        type = types[i]
        for m1 in m
            type = type-type&m1.featureMask + m1.featureMask & m1.valueMask
        end
        push!(newTypes,type)
    end
    return newTypes
end

mutable struct AllMask
    featureMask
    valueMask
end

function getTypeMaskFrom(filepath::String, datapath::String)
    #получение маски со списком Features из аттрибутов
    attr = h5readattr(filepath, datapath)
    mask = parseType(attr)
    newmask = getMask(mask)
end

function checkType(type, mask::AllMask...)
    #проверка типа на соответствие TypeMask
    res = true
    F = Dict()
    for m in mask
        if !isempty(F) & haskey(F,m.featureMask)
            F[m.featureMask] |= checkType(type, m) #добавляем по "ИЛИ" типы с одинаковыми featureMask
        else
            F[m.featureMask] = checkType(type, m)
        end
    end
    for (key, val) in F
        res &= val #добавляем по "И" типы с разными featureMask
    end
    return res
end

function checkType(type, mask::AllMask)
    res = (type & mask.featureMask) == mask.valueMask
end

function getMask(mask::Dict)
    #получение маски из прочитанного словаря (из аттрибутов) в новый словарь с featureMask и valueMask
    newMask = Dict{String, Any}()
    for (key, val) in mask
        if !isa(val,Dict)
            newMask[key] = AllMask(val,val)
            newMask["Not"*key] = AllMask(val,0)
        else
            for (key2, val2) in val
                if val2 != 0 && !isequal(key2,"Mask")
                    newMask[key*"."*key2] = AllMask(val["Mask"],val2)
                end
            end
        end
    end
    return(newMask)
end

function parseType(atr)
    #преобразование аттрибутов в Dict маски типов
    mask = Dict{String, Any}()
    for str in atr
        if match(r"Type",str[1]) !== nothing
            sbstr = split(str[1],".")
            if length(sbstr[2:end]) > 1
                if !haskey(mask, sbstr[2])
                    mask[sbstr[2]] = Dict{String, Any}()
                end
                mask[sbstr[2]][sbstr[3]] = str[2]
            else
                mask[sbstr[2]] = str[2]
            end
        end
    end
    return(mask)
end
