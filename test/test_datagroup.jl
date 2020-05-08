
localIP =  Sockets.localhost
DG = dg_new(localIP,8888,"QRS", "QPoint")
DG.data["QPoint"].data[2]("0","500","500")
