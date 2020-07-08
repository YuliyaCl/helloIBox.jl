# helloIBox

#### NOTE!   
0. Julia должна быть запущена с правами админа! Иначе IBox не поднимется 
1. Сборка бокса лежит в директории: Y:\Yuly\IBox .Но надо сохранить где-то локально, иначе не запустится 
2. dat - файл не загружен в репозиторий, поэтому в локальную копию его надо положить самостоятельно. Тесты написаны под oxy115829.dat 
Скопировать с сервера: X:\БазаСпиро\oxy115829.dat в директорию, на каторой запускается сервер
3. Если не было ручных правок, то все запросы передаются в бокс без изменений. Если был ручные правки сегментов QRS, то запрос к ним (точнее, началу и ширине) направляется в создаваемый на сервере объект, который содержит измененные сегменты. Важно! Объект ищется по именни группы - если использовать имя QRS при создании правок, то все последующие запросы тоже должны содержать имя группы QRS, а не Mark/QRS или что-то еще.


#### Установка
В julia REPL:
```
] add git@github.com:YuliyaCl/helloIBox.jl.git
```

#### запуск сервера в Julia:
```
] activate .
using helloIBox
using Sockets
using HTTP

localIP =  Sockets.localhost
port = 8080
pathToIBox = "C:/Temp/IBox/IBoxLauncher.exe" #здесь, конечно, надо свой адрес указать
start_server(""; localIP = localIP, port = port) #стартуем сервер-посредник
```

#### запустить бокс на файле. используем тот же IP, но порт 8888
```
"http://$localIP:$port/api/runIBox?res=oxy115829.dat&IBox_port=8888&IBox_path=$pathToIBox&IBox_host=$localIP" #запускаем бокс
```
У Бокса конфигурация по умолчанию с классификатором - ConfigClsWebApi, разметка 000. Однако, можно в параметрах задать иную конфигурацию/имя разметки, а также выбрать открытие разметки по ее имени. Для этого в запросе указываются параметры: config=ИмяКонфигурации; resName=Имя разметки; arg=Доп.Строка в консоль запуска. Например:
```
#запускаем бокс с конфигом БЕЗ классификатора и пишем в разметку 111
"http://$localIP:$port/api/runIBox?res=oxy115829.dat&IBox_port=8888&IBox_path=$pathToIBox&IBox_host=$localIP&config=IBTestWebApi&resName=111" 

#запуск "открыть бокс с разметкой 111", откроется уже имеющаяся разметка что бы там ни было - не надо ждать прогона
"http://$localIP:$port/api/runIBox?res=oxy115829.dat&IBox_port=8888&IBox_path=$pathToIBox&IBox_host=$localIP&config=IBOpen&resName=111&arg=-open" 
```

#### закрытие бокса
```
"http://$localIP:$port/api/Close"
```
#### закрытие сервера
```
"http://$localIP:$port/api/closeServer"
```
#### получение тега (имени) данного 
Многие данные записаны по неописательным именам (например, каналы ЭКГ: Ecg,Ecg_1 ... и тд).Чтобы получить тег данных (например, имя канала), используйте getDataTag
```
 "http://$localIP:$port/api/getDataTag?res=oxy115829.dat&dataName=Ecg_2"
 ```
 
 #### получение дерева данных
Возвращает структуру данных в JSON-формате
```
 "http://$localIP:$port/api/getDataTree"
 ```


#### обращение к данным с помощью getData 
Индексы в наборах данных идут от 0. Если не заданы to и count, то берутся ВСЕ элементы набора.
from-to/count в ЭЛЕМЕНТАХ МАССИВА

```
#запрос частоты дискретизации:
"http://$localIP:$port/api/getData?res=oxy115829.dat&dataName=Freq&index=0&from=0&count=1

 #запрос 1-го отведения ЭКГ. Чтобы запрасить 1-й канал, то надо указать index=0
"http://$localIP:$port/api/getData?res=oxy115829.dat&dataName=EcgRecalc&index=0&from=0&count=20"

 #запрос 2-го отведения ЭКГ, через нижнее подчеркивание можно задавать индекс для данных
"http://$localIP:$port/api/getData?res=oxy115829.dat&dataName=EcgRecalc_1&from=0&count=20"

#запрос первых 30 WidthQRS
"http://$localIP:$port/api/getData?res=oxy115829.dat&dataName=WidthQRS&index=0&from=0&count=30" 
```
#### запрос данных в интервале и по нескольким полям
При запросе с getStructData ВСЕГДА from-to/count в ТОЧКАХ ИСХОДНОГО СИГНАЛА
```
#точки Q и ширина QRS в интервале с 100 по 120 (отсчеты исходного сигнала)
"http://$localIP:$port/api/getStructData?res=oxy115829.dat&dataName=QRS&fields=QPoint,WidthQRS&index=0&from=100&count=20"
```

#### ручные правки сегментов
Сейчас доступно и протестировано только для QRS (добавить/удалить). Надо положить в body запроса  JSON-файл с содержанием:
```
{
    "chName": "QRS",
    "targetData": "/Mark/QRS/",
    "command": {
        "id": "ADD_SEGMENT",
        "args": {
            "ibeg": [10, 30, 50],
            "iend": [20, 45, 55],
            "type": "QRS"
        }
    },
    "fromto": [1, 150]
}
```
Более подробно о правках тут: https://docs.google.com/document/d/1311ZdQOyz3U6YEF1_FFphtpP3f7o4t_DD-u-7KdMMG4/edit
Сам текст запроса (+ JSON в боди):
```
"http://$localIP:$port/api/manualChange?res=oxy115829.dat"
```
