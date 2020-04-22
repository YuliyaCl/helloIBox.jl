res = HTTP.request("GET", "http://$localIP:8888/apibox/getData?dataName=Freq&res=oxy115829.dat&from=0&count=1&index=0")
f=res.body
toInt = reinterpret(Int32, base64decode(f)) |> collect

res = HTTP.request("GET", "http://$localIP:8888/apibox/getData?dataName=Freq&res=oxy115829.dat&from=0&count=0&index=0")
f=res.body
toInt = reinterpret(Int32, base64decode(f)) |> collect


res = HTTP.request("GET", "http://$localIP:8888/apibox/getData?dataName=Freq&res=oxy115829.dat&from=0&count=1&index=0")
f=res.body
toInt = reinterpret(Int32, base64decode(f)) |> collect
