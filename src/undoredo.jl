#лежит внутри DataGroup и хранит историю операций
mutable struct UndoRedoTool
    history::Vector{String} #храним операции пользователя
    sourse #DataGroup #источник данных
    state::Int64 #в каком состоянии находимся (0 - не было изменений)
    UndoRedoTool() = new([],[],0)
end
