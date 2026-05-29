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
del target\uitiles 2>nul
del target\ovr-save 2>nul
del target\ovr-load 2>nul
del target\ovr-inspect 2>nul

REM One disk for both platforms: the program detects Xemu vs real hardware at
REM boot ($D60F bit 5) and applies the sprite-X correction at runtime.
.\64tass.exe --cbm-prg -a src\main.asm -l target\mega-simcity.lbl -L target\mega-simcity.lst -o target\mega-simcity
if errorlevel 1 exit /b 1

.\64tass.exe --cbm-prg -a src\assets\tileset.asm -l target\tileset.lbl -L target\tileset.lst -o target\tileset
if errorlevel 1 exit /b 1

.\64tass.exe --cbm-prg -a src\assets\ui_tiles.asm -l target\uitiles.lbl -L target\uitiles.lst -o target\uitiles
if errorlevel 1 exit /b 1

REM Overlays (ovr-*) import the main-game label file, so they must build AFTER main.
.\64tass.exe --cbm-prg -a src\overlays\ovr-save.asm -L target\ovr-save.lst -o target\ovr-save
if errorlevel 1 exit /b 1

.\64tass.exe --cbm-prg -a src\overlays\ovr-load.asm -L target\ovr-load.lst -o target\ovr-load
if errorlevel 1 exit /b 1

.\64tass.exe --cbm-prg -a src\overlays\ovr-inspect.asm -L target\ovr-inspect.lst -o target\ovr-inspect
if errorlevel 1 exit /b 1

cd target
..\c1541.exe -format "simcity,01" d81 mega-simcity.d81
if errorlevel 1 exit /b 1
..\c1541.exe -attach mega-simcity.d81 -write mega-simcity mega-simcity
if errorlevel 1 exit /b 1
..\c1541.exe -attach mega-simcity.d81 -write tileset tileset
if errorlevel 1 exit /b 1
..\c1541.exe -attach mega-simcity.d81 -write uitiles uitiles
if errorlevel 1 exit /b 1
..\c1541.exe -attach mega-simcity.d81 -write ovr-save ovr-save
if errorlevel 1 exit /b 1
..\c1541.exe -attach mega-simcity.d81 -write ovr-load ovr-load
if errorlevel 1 exit /b 1
..\c1541.exe -attach mega-simcity.d81 -write ovr-inspect ovr-inspect
if errorlevel 1 exit /b 1
cd ..

echo Built target\mega-simcity.d81
