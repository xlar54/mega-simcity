@echo off
setlocal
if not exist target mkdir target
if not exist target\userprofile\AppData\Roaming mkdir target\userprofile\AppData\Roaming
set "USERPROFILE=%CD%\target\userprofile"
set "APPDATA=%USERPROFILE%\AppData\Roaming"

del target\*.d81 2>nul
del target\*.lst 2>nul
del target\*.lbl 2>nul
del target\mega-simcity 2>nul
del target\tileset 2>nul

.\64tass.exe --cbm-prg -a src\main.asm -l target\mega-simcity.lbl -L target\mega-simcity.lst -o target\mega-simcity
if errorlevel 1 exit /b 1

.\64tass.exe --cbm-prg -a src\assets\tileset.asm -l target\tileset.lbl -L target\tileset.lst -o target\tileset
if errorlevel 1 exit /b 1

cd target
..\c1541.exe -format "simcity,01" d81 mega-simcity.d81
if errorlevel 1 exit /b 1
..\c1541.exe -attach mega-simcity.d81 -write mega-simcity mega-simcity
if errorlevel 1 exit /b 1
..\c1541.exe -attach mega-simcity.d81 -write tileset tileset
if errorlevel 1 exit /b 1
cd ..

echo Built target\mega-simcity.d81
