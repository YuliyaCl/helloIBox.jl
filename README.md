# helloIBox

#### NOTE!   
0. Julia должна быть запущена с правами админа! Иначе IBox не поднимется 
1. Сборка бокса лежит в директории: Y:\Yuly\IBox .Но надо сохранить где-то локально, иначе не запустится 
2. dat - файл не загружен в репозиторий, поэтому в локальную копию его надо положить самостоятельно. Тесты написаны под oxy115829.dat 
Всязть с сервера: X:\БазаСпиро

#### Установка
В julia REPL:
```
] add git@github.com:YuliyaCl/helloIBox.jl.git
```

#### запуск сервера в Julia:
```] activate .
using helloIBox
using Sockets
using HTTP

localIP =  Sockets.localhost
port = 8080
pathToIBox = "C:/Temp/IBox/IBoxLauncher.exe"
start_server(""; localIP = localIP, port = port) #стартуем сервер-посредник
```

#### запустить бокс на файле
```
"http://$localIP:$port/api/runIBox?res=oxy115829.dat&IBox_port=8888&IBox_path=$pathToIBox&IBox_host=$localIP" #запускаем бокс 
```
#### закрытие сервера
```
"http://$localIP:$port/api/closeServer"
```

#### закрытие бокса
```
"http://$localIP:$port/api/Close"
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

 #запрос 1-го отведения ЭКГ. Если нет индекса,он принимается =0
"http://$localIP:$port/api/getData?res=oxy115829.dat&dataName=EcgRecalc&from=0&count=20"

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

#### комментарии
Сейчас нет интерактива и в принципе моэжно пользоватсья боксом напрямую. Но потом он появится=)
