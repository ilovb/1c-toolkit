**1c-toolkit** - это коллекция различных полезных скриптов на языке [Lua](http://ru.wikipedia.org/wiki/Lua) для работы с файлами платформы [1С:Предприятие 8](http://v8.1c.ru/overview/)

----------
состав версии 0.1.5:

- **cf\_reader.lua** - модуль для чтения [файлов конфигураций 1С](http://www.richmedia.us/post/2011/01/18/cf-file-format-1c-8-compatible.aspx) (cf, epf, erf)
- **cf\_inside.lua** - модуль для работы с содержимым файлов конфигураций
- **cf\_modunp.lua** - утилита командной строки для извлечения модулей из обработок и отчетов
- **cf\_unpack.lua** - утилита командной строки для распаковки файлов конфигураций в указанный каталог
- **cf\_repack.lua** - утилита командной строки для переупаковки файлов конфигураций в zip-архив
- **tsvn\_hook\_pre-commit.lua** - клиентский хук для [TortoiseSVN](http://ru.wikipedia.org/wiki/TortoiseSVN), который извлекает модули из обработок и отчетов
- **diff\_conf.lua** - утилита командной строки для сравнения отчетов по конфигурациям
- **cf\_viewer.wlua** - графическая утилита для просмотра модулей обработок и отчетов

----------
статьи на **[Infostart](http://infostart.ru/)**:

- [Распаковка CF на Lua](http://infostart.ru/public/178201/)
- [Клиентский хук для TortoiseSVN](http://infostart.ru/public/181018/)
- [Альтернативное сравнение конфигураций](http://infostart.ru/public/165529/)
- [Утилита для просмотра модулей обработок и отчетов](http://infostart.ru/public/183149/)

----------
файлы для скачивания:

* 1c-toolkit [версия 0.1.5](https://bitbucket.org/boris_coder/1c-toolkit/get/0.1.5.zip)
	* [1c-toolkit\_v0.1.5\_win\_x86.exe](https://bitbucket.org/boris_coder/1c-toolkit/downloads/1c-toolkit_v0.1.5_win_x86.exe)
	* [1c-toolkit\_v0.1.5\_win\_x64.exe](https://bitbucket.org/boris_coder/1c-toolkit/downloads/1c-toolkit_v0.1.5_win_x64.exe)
* компилятор LuaJIT:
	* [LuaJIT 2.0.1 with Hotfix#1 / win / x86 / built with Windows SDK 8 /  
	includes proxy lua5.1.dll and wluajit.exe](https://bitbucket.org/boris_coder/1c-toolkit/downloads/LuaJIT_201_msvc_win_x86.zip)
	* [LuaJIT 2.0.1 with Hotfix#1 / win / x64 / built with Windows SDK 8 /  
	includes proxy lua5.1.dll and wluajit.exe](https://bitbucket.org/boris_coder/1c-toolkit/downloads/LuaJIT_201_msvc_win_x64.zip)
* бинарные модули (lfs.dll):
	* [clibs\_win\_x86.zip](https://bitbucket.org/boris_coder/1c-toolkit/downloads/clibs_win_x86.zip)
	* [clibs\_win\_x64.zip](https://bitbucket.org/boris_coder/1c-toolkit/downloads/clibs_win_x64.zip)
* библиотеки (zlib1.dll, miniz.dll, tinfl.dll, libiconv.dll):
	* [bin\_win\_x86.zip](https://bitbucket.org/boris_coder/1c-toolkit/downloads/bin_win_x86.zip)
	* [bin\_win\_x64.zip](https://bitbucket.org/boris_coder/1c-toolkit/downloads/bin_win_x64.zip)
* [IUP](http://ru.wikipedia.org/wiki/IUP) (iuplua51.dll, iup.dll)
	* [iup\_x86.zip](https://bitbucket.org/boris_coder/1c-toolkit/downloads/iup_x86.zip)
	* [iup\_x64.zip](https://bitbucket.org/boris_coder/1c-toolkit/downloads/iup_x64.zip)
* [Распространяемый пакет Visual C++ для Visual Studio 2012](http://www.microsoft.com/ru-ru/download/details.aspx?id=30679)

----------
