#лежит внутри DataGroup и хранит историю операций
mutable struct UndoRedoTool
    history::Vector{String} #храним операции пользователя
    sourse #DataGroup #источник данных
    state::Int64 #в каком состоянии находимся (0 - не было изменений)
    UndoRedoTool() = new([],[],0)
end


#отмена для большой истории правок
function undo!(AllObj::Dict,baseIP::IPv4,port::Union{String,Int64})
    if !haskey(AllObj,"history") || AllObj["state"]==0
        return AllObj
    end
    #определяем, над кем была последняя операция
    manualEvent = JSON.parse(AllObj["history"][AllObj["state"]])
    #понижаем статус
    AllObj["state"] -= 1

    #сопоставляем внешние названия и внутренние данные
    gp_name = manualEvent["chName"]

    #откатываем последнего товарища
    undo!(AllObj["dataStorage"][gp_name],baseIP, port)

    return AllObj
end

#возвращение для большой истории правок
function redo!(AllObj::Dict,baseIP::IPv4,port::Union{String,Int64})
    if !haskey(AllObj,"history") ||  AllObj["state"] == size(AllObj["history"],1)
        return AllObj
    end
    #повышаем статус
    AllObj["state"] += 1
    #определяем, над кем была операция
    manualEvent = JSON.parse(AllObj["history"][AllObj["state"]])
    #сопоставляем внешние названия и внутренние данные
    gp_name = manualEvent["chName"]

    #откатываем последнего товарища
    redo!(AllObj["dataStorage"][gp_name],baseIP, port)

    return AllObj
end

function Base.joinpath(a::Vector{T}) where T
    Path = a[1]
    for i=2:length(a)
        Path = joinpath(Path,a[i])
    end
    Path
end


#перевод информации о действии пользователя из словаря в строку
#данные берутся из JSON
#action - словарь, собранный из JSON с данными о команде
function commandToString(action::Dict,resStr = "")
    for key in keys(action)
        if isa(action[key],Dict)
            #"=>" значит переход на следующий уровень вложенности словаря
            resStr = commandToString(action[key],resStr)
        else
            if resStr == ""
                resStr = key*": "*string(action[key])
            else
                resStr = resStr*"; "*key*": "*string(action[key])
            end
        end
    end
    resStr
end
