set DEST_DIR=.\build\src
@echo off
del %DEST_DIR%\*.v
del %DEST_DIR%\*.sv
del %DEST_DIR%\include\*.vh
del %DEST_DIR%\include\*.svh

if not exist ".\build" mkdir .\build
if not exist ".\build\src" mkdir .\build\src
if not exist ".\build\src\include" mkdir .\build\src\include
:: pick core/soc source file
cd .\src\core
for /f "delims=" %%a in ('dir /a-d /b /s *.v') do (copy "%%a" ..\..\build\src)
for /f "delims=" %%a in ('dir /a-d /b /s *.sv') do (copy "%%a" ..\..\build\src)
for /f "delims=" %%a in ('dir /a-d /b /s *.svh') do (copy "%%a" ..\..\build\src\include)
cd ..\misc
for /f "delims=" %%a in ('dir /a-d /b /s *.v') do (copy "%%a" ..\..\build\src)
for /f "delims=" %%a in ('dir /a-d /b /s *.sv') do (copy "%%a" ..\..\build\src)
:: find soc source file
cd ..\soc
for /f "delims=" %%a in ('dir /a-d /b /s *.v') do (copy "%%a" ..\..\build\src)
for /f "delims=" %%a in ('dir /a-d /b /s *.sv') do (copy "%%a" ..\..\build\src)
for /f "delims=" %%a in ('dir /a-d /b /s *.svh') do (copy "%%a" ..\..\build\src\include)
for /f "delims=" %%a in ('dir /a-d /b /s *.vh') do (copy "%%a" ..\..\build\src\include)
cd ..\..
::如果定义是使用仿真，则使用仿真文件覆盖掉include和综合用的src文件
if %1==sim (
    copy /Y .\src\sim\soc_tb\*.sv .\build\src
    copy /Y .\src\sim\soc_tb\*.v .\build\src
    copy /Y .\src\sim\soc_tb\*.vh .\build\src\include
    copy /Y .\src\sim\soc_tb\*.svh .\build\src\include
) else if %1==e4fpmk7mmb (
    copy /Y .\src\board\xilinx\*.sv .\build\src
    copy /Y .\src\board\xilinx\*.v .\build\src
    copy /Y .\src\board\xilinx\*.vh .\build\src\include
    copy /Y .\src\board\xilinx\*.svh .\build\src\include
)
echo =====================================================
echo all files for syn/sim has been copy to ./build\src
echo font.txt is the rom file for VGA display
echo remember to add *_define, *_config file to project
echo =====================================================
