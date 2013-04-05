@SET LUA_CPATH=%~dp0\clibs\?.dll;%~dp0\clibs\?51.dll;;
@SET PATH=%~dp0;%~dp0\bin;%PATH%
@"%~dp0\luajit.exe" %*