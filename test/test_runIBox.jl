using HTTP
using Sockets


IBoxPath = `"Y:/Yuly/IBox/IBoxLauncher.exe"`
fileName = `"Y:/Yuly/oxy115829.dat"`
arguments = `-config:IBOpen -xreg -finalize -res:test3`
command = join([IBoxPath fileName arguments])
@async run(`C:/Temp/IBox/IBoxLauncher.exe "C:/Temp/oxy115829.dat"  -config:IBTestWebApi -WebAPISrc[port=8888] -finalize |debug=true`)
run(`C:/Temp/IBox/IBoxLauncher.exe "C:/Temp/oxy115829.dat"  -config:IBTestWebApi -WebAPISrc[port=8888] -finalize`)


localIP =  Sockets.localhost
port = 8888
#отправляем ручную правку на сервер, смотрим, что не свалилось. саму судь сведения проверяем в датагруппе
r=HTTP.request("GET","http://$localIP:$port/apibox/getCountDataInInterval?dataName=QPoint&index=0&from=0&to=1000&count=1000")
r=HTTP.request("GET","http://$localIP:$port/apibox/getData?dataName=QPoint&index=0&from=0&to=10&count=100")
dp =  "C:\\Users\\yzh\\.julia\\dev\\helloIBox\\src\\..\\test\\oxy115829.dat"
dp =  "C:\\Users\\yzh\\.julia\\dev\\helloIBox\\test\\oxy115829.dat"
dp =  `"C:/Temp/oxy115829.dat"`
IBox_path = `C:/Temp/IBox/IBoxLauncher.exe`
args = `-config:IBTestWebApi -WebAPISrc[port=8888] -finalize`
comand = Cmd([IBox_path,dp,args])
comandcmd = Cmd([comand],ignorestatus=true, detach=false)
run(IBox_path,dp,args)


@async run(`C:/Temp/IBox/IBoxLauncher.exe C:\\Users\\yzh\\.julia\\dev\\helloIBox\\src\\..\\test\\oxy115829.dat  -config:IBTestWebApi -WebAPISrc[port=8888] -finalize`)

# ` ` - такие кавычки значат Cmd строку
dp = `"C:/Temp/oxy115829.dat"`
IBox_path = `C:/Temp/IBox/IBoxLauncher.exe`
args = `-config:IBTestWebApi -WebAPISrc[port=8888] -finalize`
command = join([IBox_path,dp,args]) #так соединяет коряво

# как получить:
needStr = `C:/Temp/IBox/IBoxLauncher.exe "C:/Temp/oxy115829.dat"  -config:IBTestWebApi -WebAPISrc[port=8888] -finalize`


dp = "C:/Temp/oxy115829.dat"
IBox_path = "C:/Temp/IBox/IBoxLauncher.exe"
args = "-config:IBTestWebApi -WebAPISrc[port=8888] -finalize"
comand = Cmd([IBox_path,dp,args])
#выдает
ihaveStr_1 =`C:/Temp/IBox/IBoxLauncher.exe C:/Temp/oxy115829.dat '-config:IBTestWebApi -WebAPISrc[port=8888] -finalize'`
run(comand) #бокс запускается, но чет не работает там
comand = join([IBox_path," ",dp," ",args])
cmd_com = Cmd([comand])
#можно так, но надо сделать кавычки вокруг имени файла, но уменя не получается =((
ihaveStr_2 = `'C:/Temp/IBox/IBoxLauncher.exe C:/Temp/oxy115829.dat -config:IBTestWebApi -WebAPISrc[port=8888] -finalize'`
#и оно не работает
run(cmd_com)
