# helloIBox

#### NOTE!   
0. Julia должна быть запущена с правами админа! Иначе IBox не поднимется 
1. Сборка бокса лежит в директории: Y:\Yuly\IBox .Но надо сохранить где-то локально, иначе не запустится 
2. dat - файл не загружен в репозиторий, поэтому в локальную копию его надо положить самостоятельно. Тесты написаны под oxy115829.dat 
Всязть с сервера: X:\БазаСпиро


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
пока нет, н оскоро будет
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
Если запрашиваются данные-позиции, то от-до интерпритируется как интервал в исходных точках. Например, запрос QPoint от 10 и count 100 выдаст те QPoint, которые укладываются в интервал от 10 до 110

```
#запрос частоты дискретизации:
"http://$localIP:$port/api/getData?res=oxy115829.dat&dataName=Freq&index=0&from=0&count=1

 #запрос 1-го отведения ЭКГ. Если нет индекса,он принимается =0
"http://$localIP:$port/api/getData?res=oxy115829.dat&dataName=EcgRecalc&from=0&count=20"

 #запрос 2-го отведения ЭКГ, через нижнее подчеркивание можно задавать индекс для данных
"http://$localIP:$port/api/getData?res=oxy115829.dat&dataName=EcgRecalc_1&from=0&count=20"

#запрос точки Q на интервале от 0 на 300 точек дальше
"http://$localIP:$port/api/getData?res=oxy115829.dat&dataName=QPoint&index=0&from=0&count=300"

#запрос первых 30 WidthQRS
"http://$localIP:$port/api/getData?res=oxy115829.dat&dataName=WidthQRS&index=0&from=0&count=30" 
```
#### обращение к данным с помощью getDataRaw
При запросе с getDataRaw ВСЕГДА выдаются данные from - to/count в штуках в массиве данных
```
"http://$localIP:$port/api/getDataRaw?res=oxy115829.dat&dataName=QPoint&index=0&from=0&count=300" #запрос 300 штук точек Q  от 0 индекса
```

#### проблемы запросов к данным
Сейчас решается вопрос согласования запросов. Так, запросив точки Q на интервале от 0 на 300  нельзя пока получить для них, например, WidthQRS. Это будет решено.

