mutable struct AllMask
    featureMask
    valueMask
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
function setbit(mask::Dict,types::Vector{T},bitName::Vector{String}) where T
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

#построение дерева классов на основе класса и подкласса, с сохранением данных индексации попавших в категорию элементов
function buildQRStree(QPoint,Class, SubClass)

    unCl = unique(Class)
    QPoint = QPoint[1:length(Class)] #обрезаем по кол-ву классифицированных комплексов

    unSubCl = unique(SubClass)

    treeClasses = Dict{String,Any}()
    treeClasses["nodes"] = []
    treeClasses["name"] = "allClasses"
    treeClasses["size"] = length(Class)

    for i = 1:length(unCl)
        isCl = Class.==unCl[i]
        node =  Dict{String,Any}()
        node["nodes"] = []
        node["name"] = unCl[i]
        node["size"] = sum(isCl)
        node["QPoint"] = QPoint[isCl]
        for j = 1:length(unSubCl) #теперь добавляем подклассы
            isSubCl= (SubClass.== unSubCl[j]) .& isCl

            subnode =  Dict{String,Any}()
            subnode["nodes"] = []
            subnode["name"] = unSubCl[j]
            subnode["size"] = sum(isSubCl)
            subnode["QPoint"] = QPoint[isSubCl]
            push!(node["nodes"],subnode)
        end
        push!(treeClasses["nodes"],node)
    end


    result = JSON.json(treeClasses)
    return result
end
