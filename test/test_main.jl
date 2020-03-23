# using Cxx
# using Libdl
#
# const path_to_lib = "Y:/Yuly/ibjuly/out/build/x64-Release"
# addHeaderDir(path_to_lib, kind=C_System)
# Libdl.dlopen(path_to_lib * "/ibjuly.dll", Libdl.RTLD_GLOBAL)
# cxxinclude("Y:/Yuly/ibjuly/ibjuly.h")
#
# hello_class = @cxxnew CIBJuly()

using CxxWrap
@wrapmodule(joinpath("Y:/Yuly/ibjuly/out/build/x64-Release","ibjuly.dll"))

#  function __init__()
#    @initcxx
#  end
