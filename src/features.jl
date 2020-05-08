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
