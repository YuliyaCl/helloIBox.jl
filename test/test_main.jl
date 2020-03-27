using Libdl

#проверяем выполнение всех функций в dll-ке
path_to_lib = "test/dll_test-master/x64/Release/Dll_test.dll"

x_int = ccall((:sum_int, path_to_lib), Cint,(Cint,Cint),2,3) # 5
x_float = ccall((:sum_float, path_to_lib), Cfloat,(Cfloat,Cfloat),2.0,3.2) #5.20
x_double = ccall((:sum_double, path_to_lib), Cdouble,(Cdouble,Cdouble),1.00,1.00) #2.0
x_arr = ccall((:print_array, path_to_lib), Cvoid,(Array{Cdouble},Cint),[1.00, 2.00, 3.00],3) #странный оут
x_add1 = ccall((:add_one, path_to_lib), Cfloat,(Cfloat,),5.0) # 6.00

path_to_ibdll = "Y:/Yuly/ibjuly/out/build/x64-Release/ibjuly.dll" 
y = ccall((:CreateInterface, path_to_ibdll),Cvoid,()) # 5
getenv
getMessage
