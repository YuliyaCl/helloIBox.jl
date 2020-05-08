"""
Содержит функции:
searchinrange(begs::Vector, ends::Vector, from, to) - поиск диапазона сегментов,пересекающихся с from-to

seg_in_range(segs::StructArray, from,to) - аналог searchinrange для StructArray

delete_seg(segs::StructArray, from, to) - удаление сегментов, попавших под диапазон rom-to

add_seg(segs::StructArray, newSeg::StructArray, mode) - добавление сегментов по 3-м режимам:"rewrite"(удаление всего, что пересекалось),
"simpleAdd"(тупо добавить и отсортировать), "raw"(слить,расширяя границы при пересечении)"

addRawSeg(seg1::StructArray,seg2::StructArray) - слияние seg1 с seg2 ,расширяя границы при пересечении

mergeIntersections(seg::StructArray) - удаление внутренних пересечений в seg

segCompare(seg1::StructArray, seg2::StructArray) - сравнение двух наборов на пересечение сегментов мд ними

segMinus(seg1::StructArray, seg2::StructArray) - удаление из seg1 сегментов, наложившихся на seg2. (в 2х версиях)
"""

using StructArrays
#сегмент - StructArray с обязательными ibeg, iend и необязательным набором признаков
#сегменты упорялочены по возрастанию
function searchinrange(begs::Vector{T}, ends::Vector{T}, from, to) where T
    i1 = searchsortedfirst(ends, from)
    i2 = searchsortedlast(begs, to)
    i1:i2 # соответствие с searchsorted
end

function seg_in_range(segs::StructArray, from,to)
    #определение сегментов, пересекающихся с диапазоном [from-to]
    s_range = searchinrange(segs.ibeg, segs.iend, from, to)
    segsInRange = segs[s_range]
    # segsInRange = filter(x->sign(x.ibeg-to) != sign(x.iend-from), LazyRows(segs))
    return segsInRange
end

"""
удаление сегментов, которые наложились на диапазон [from-to]
"""
function delete_seg(segs::StructArray, from, to)
    s_range = searchinrange(segs.ibeg, segs.iend, from, to)
    Ns = length(segs)
    i=1:Ns
    segs_reduced = StructArray(ibeg=Int[], iend=Int[], type = Int[])
    #segs_reduced =  StructArray{eltype(Int64)}(undef, 0) #так не пашет
    if !isempty(s_range)
    #if range - > ошибку дает, что небулевое значение в булевом контексте
    #результат выходил как вектор Struct-Arrays-ов, так что сделала так
        append!(segs_reduced,segs[1:s_range.start-1])
        append!(segs_reduced,segs[s_range.stop+1:end])
        #segs_reduced = segs[idTake]
    else
        segs_reduced = copy(segs) # !!! все массивы типа mutable - присваиваются и передаются в функции по ссылке
    end
    return segs_reduced
end

"""
добавление сегментов
mode = "rewrite"(удаление всего, что пересекалось),
"simpleAdd"(тупо добавить и отсортировать), "raw"(слить,расширяя границы при пересечении)
"""
function add_seg(segs::StructArray, newSeg::StructArray, mode)
    #seg_out = StructArray{eltype(Int)}(undef, 0) # вот так можно создать пустой массив
    #seg_out = StructArray(ibeg=typeof(newSeg.ibeg)(), iend=typeof(newSeg.iend)(), type = typeof(newSeg.type)())#type = typeof(newSeg[1].type)())
    seg_out = StructArray(ibeg=Int[], iend=Int[], type=Int[])
    if mode=="simpleAdd"

        NsAdd = length(newSeg)
        NsAdd > 0 || return copy(segs)

        i0 = i1 = 1
        for i=1:NsAdd
            #индекс первого бОльшего сегмента
            i1 = searchsortedfirst(segs.ibeg, newSeg[i].ibeg)
            temp_t_right = @view segs[i0:i1-1]
            append!(seg_out, temp_t_right) # ничего страшного, если пустой добавится - ничего не произойдет
            push!(seg_out, newSeg[i]) # push - для элементов, append - для векторов
            i0 = i1
        end
        temp_t_right = @view segs[i1:end]
        append!(seg_out, temp_t_right)

    elseif mode=="rewrite"
        NsAdd = length(newSeg)
        seg_out = copy(segs)
        for i = 1:NsAdd
            seg_out = delete_seg(seg_out, newSeg[i].ibeg, newSeg[i].iend)
        end
        seg_out = add_seg(seg_out, newSeg, "simpleAdd")
    elseif mode=="raw"
        seg_out = addRawSeg(segs,newSeg)
    end

    return seg_out
end

"""
Вспомогательные функции для addRawSeg()
"""
function addTempSeg(tempSeg,newSeg)
    if tempSeg.ibeg != 0
        if tempSeg.iend-tempSeg.ibeg > 0
            if !isa(newSeg.ibeg,UndefInitializer)
                # @info newSeg, tempSeg
                #так плохо, но я не знаю, как иначе
                ib = [newSeg.ibeg tempSeg.ibeg]
                ie = [newSeg.iend tempSeg.iend]
                tp = [newSeg.type tempSeg.type]
                newSeg = (ibeg = ib, iend = ie, type = tp)
            else
                newSeg = tempSeg
            end
        end
        tempSeg = (ibeg = 0, iend = 0, type = 0)
    end
    return newSeg, tempSeg
end

function sortSeg(seg::StructArray)
    return seg[sortperm(seg.ibeg)]
end

"""
Добавление сегментов из набора 2 в набор 1 с расширением сегментов при пересечении
"""
function addRawSeg(seg1::StructArray,seg2::StructArray)
    #проверка на внутренние пересечения. ИЛИ ЕЕ НАРУЖУ ВЫНЕСТИ??
    seg1 = mergeIntersections(seg1)
    seg2 = mergeIntersections(seg2)

    N1 = length(seg1)
    N2 = length(seg2)
    stop = false
    toDel1 = falses(N1)
    toDel2 = falses(N2)

    newSeg =  (ibeg = undef, iend = undef, type=undef) # StructArray(ibeg=Int[], iend=Int[], type=Int[])
    tempSeg = (ibeg = 0, iend = 0, type=0)
    i=j=1
    while !stop
        if seg1[i].iend < seg2[j].ibeg # Seg1 кончается раньше, чем начинается Seg2
            newSeg, tempSeg = addTempSeg(tempSeg, newSeg)
            if i<N1; i+=1;continue
            else stop = true end
        elseif seg2[j].iend < seg1[i].ibeg #Seg2 кончается раньше, чем начинается Seg1
            newSeg, tempSeg = addTempSeg(tempSeg, newSeg)
            if j<N2; j+=1;continue
            else stop = true end
        else #сегменты пересекаются
            #и имеют одинаковые типы
            equalTypes = seg1[i].type == seg2[j].type
            if equalTypes
                toDel1[i] = toDel2[j] = true
                if tempSeg.ibeg == 0
                    tempSeg = (ibeg = minimum([seg1[i].ibeg,seg2[j].ibeg]),
                    iend = maximum([seg1[i].iend,seg2[j].iend]),
                    type = seg1[i].type)
                else
                    tempSeg = (ibeg = tempSeg.ibeg,
                    iend = maximum([seg1[i].iend,seg2[j].iend]),
                    type = seg1[i].type)
                end
            end
                if seg1[i].iend >= seg2[j].iend
                    if j<N2; j+=1; continue
                    else stop = true end
                else
                    if i<N1; i+=1;continue
                    else stop = true end
            end
        end
        newSeg, tempSeg = addTempSeg(tempSeg, newSeg)
    end
    clearSegs1 = seg1[.!toDel1]
    clearSegs2 = seg2[.!toDel2]
    addSeg = []
    if !isempty(clearSegs1)
        addSeg = clearSegs1
    end
    if !isempty(clearSegs2)
        if !isempty(addSeg)
            append!(addSeg,clearSegs2)
        else
            addSeg = clearSegs2
        end
    end
    if !isempty(newSeg) && !isa(newSeg.ibeg,UndefInitializer)
        #newSeg был туплом, надо сделать страктэрреем
        if !isa(newSeg.ibeg,Array)
            newSegStr = StructArray(ibeg = [newSeg.ibeg], iend = [newSeg.iend], type = [newSeg.type])
        else
            newSegStr = StructArray(ibeg = newSeg.ibeg, iend = newSeg.iend, type = newSeg.type)
        end
        if !isempty(addSeg)
            append!(addSeg, newSegStr)
        else
            addSeg = newSegStr
        end
    end
    # @info addSeg
    outSeg = sortSeg(addSeg)
    return outSeg
end

"""
Схлопывание пересекающихся сегментов
ВНИМАНИЕ: если есть параметры, то они похерятся
"""
function mergeIntersections(seg::StructArray)
    N = length(seg)
    if N==1
        return seg
    end
    toDel = falses(N)
    idMerged = 0 #флаг, было ли на прошлом шаге слияние
    for i=1:N-1
        if seg[i].iend>=seg[i+1].ibeg #если следующий начинается раньше конца текущего
                if seg[i].type == seg[i+1].type #если одинаковые типы пересекаются
                    toDel[i] = true # удалим текущий
                    seg[i+1] = (ibeg= seg[i].ibeg, iend = max(seg[i].iend[1], seg[i+1].iend[1]), type = seg[i].type) #у следующего удлиним начало
                end
        end
    end
    seg[.!toDel]
end

"""
сравнение двух наборов сегментов на пересечения, аналог ф-ции в MATLAB
onlySeg1, вектор сегментов Seg1, которые не пересекаются с onlySeg2 и наоборот
сегменты не должны накладываться др на др
"""
function segCompare(seg1::StructArray, seg2::StructArray)
    N1 = length(seg1)
    N2 = length(seg2)
    i=j=1
    stop = false
    commonSeg1 = falses(N1)
    commonSeg2 = falses(N2);

    if N1 == 0 || N2 == 0
        only1ind = .!commonSeg1
        only2ind = .!commonSeg2
    else
        while !stop
            #Seg1 раньше Seg2
            if seg1[i].iend < seg2[j].ibeg # Seg1 кончается раньше, чем начинается Seg2
                if i<N1
                    i+=1
                    continue
                else
                    stop = true
                end
            end
            #Seg2 раньше Seg1
            if seg2[j].iend < seg1[i].ibeg  #Seg2 кончается раньше, чем начинается Seg1
                if j<N2
                    j+=1
                    continue
                else
                    stop = true
                end
            end
            # Seg2 пересекается с Seg1
            if sign(seg1[i].ibeg -seg2[j].iend) != sign(seg1[i].iend-seg2[j].ibeg)
                commonSeg1[i] = commonSeg2[j] = true
                if seg1[i].iend >= seg2[j].iend
                    if j<N2
                        j+=1
                        continue
                    else
                        stop = true
                    end
                else
                 	if i<N1
                        i=i+1
                        continue
                    else
                        stop = true
                    end
                end
            end
        end
        only1ind =  .!commonSeg1
        only2ind =  .!commonSeg2

    end
    return only1ind, only2ind
end
"""
удаляет любые сегменты из Seg1, которые пересекаются с Seg2 (Seg1 = Seg1 - Seg2)
"""
function segMinus_(seg1::StructArray, seg2::StructArray)
    only1, only2 = segCompare(seg1, seg2)
    return seg1[only1]
end
"""
версия 2 - удаляет любые сегменты из Seg1, которые пересекаются с Seg2 (Seg1 = Seg1 - Seg2)
"""
function segMinus(seg1::StructArray, seg2::StructArray)
    N1 = length(seg1)
    N2 = length(seg2)
    i=j=1
    stop = false
    takeID = trues(N1)

    if !(N1 == 0 || N2 == 0)
        while !stop
            #Seg1 раньше Seg2
            if seg1[i].ibeg<= seg2[j].iend # начало 1 меньше конца 2
                if seg1[i].iend >= seg2[j].ibeg
                    takeID[i] = false
                end
                if i<N1
                    i+=1
                    continue
                else
                    stop = true
                end
            else
                if j<N2
                    j+=1
                    continue
                else
                    stop = true
                end
            end
        end
    end
    return seg1[takeID]
end
