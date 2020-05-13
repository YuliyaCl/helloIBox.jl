function loadMarksFromHistory(allObj::Dict, pathToHistory::String)
#чтение ручных правок из файла и применение их к текущему
    #читаем правки
    commands = []
    for line in eachline(pathToHistory)
        push!(commands, line)
    end
    N = length(commands)
    for i = 1:N-1
        segInRange = parseCommand(allObj,commands[i])
    end
    # @info allObj["history"]
    segInRange = parseCommand(allObj,commands[N])
    return segInRange
end

function writeManualMark(commands::Array{Any,1}, pathToHistory::String)
    #пишем в файл правки - JSON одной строкой
    # @info commands
    for c in commands
        writeManualMark(c,pathToHistory)
    end
end
function writeManualMark(command::String, pathToHistory::String)
    command_dict = JSON.parse(command)
    open(pathToHistory,"a") do f
        JSON.print(f, command_dict)
        write(f,'\n')
    end
end
function deleteLastCommand(pathToHistory::String)
    #удаляем последнюю строчку в файле. пока придется так
    # pathToHistory = joinpath(Base.@__DIR__, "..","test","files","MX120161019112321.test","test_history00.json")

    commands = []
    for line in eachline(pathToHistory)
        push!(commands, line)
    end

    if isfile(pathToHistory)
        rm(pathToHistory)
    end
    # @info commands
    writeManualMark(commands[1:end-1], pathToHistory)

end
