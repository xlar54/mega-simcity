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
del target\tile-edit 2>nul
del target\loader 2>nul
del target\tileset 2>nul
del target\uitiles 2>nul
del target\palette 2>nul
del target\ovr-disk 2>nul
del target\ovr-inspect 2>nul

REM One disk for both platforms: the program detects Xemu vs real hardware at
REM boot ($D60F bit 5) and applies the sprite-X correction at runtime.
.\64tass.exe --cbm-prg -a src\main.asm -l target\mega-simcity.lbl -L target\mega-simcity.lst -o target\mega-simcity
if errorlevel 1 exit /b 1

.\64tass.exe --cbm-prg -a src\tile-edit.asm -l target\tile-edit.lbl -L target\tile-edit.lst -o target\tile-edit
if errorlevel 1 exit /b 1

.\64tass.exe --cbm-prg -a src\assets\tileset.asm -l target\tileset.lbl -L target\tileset.lst -o target\tileset
if errorlevel 1 exit /b 1

.\64tass.exe --cbm-prg -a src\assets\ui_tiles.asm -l target\uitiles.lbl -L target\uitiles.lst -o target\uitiles
if errorlevel 1 exit /b 1

.\64tass.exe --cbm-prg -a src\assets\palette.asm -l target\palette.lbl -L target\palette.lst -o target\palette
if errorlevel 1 exit /b 1

REM Overlays (ovr-*) import the main-game label file, so they must build AFTER main.
.\64tass.exe --cbm-prg -a src\overlays\ovr-disk.asm -L target\ovr-disk.lst -o target\ovr-disk
if errorlevel 1 exit /b 1

.\64tass.exe --cbm-prg -a src\overlays\ovr-inspect.asm -L target\ovr-inspect.lst -o target\ovr-inspect
if errorlevel 1 exit /b 1

REM Boot loader. Imports main's .lbl to resolve main_entry, so it must build
REM AFTER main. Phase 1: loader runs on SYS, stages assets, trampoline-loads
REM mega-simcity.prg, JMPs main_entry. Main is unchanged in Phase 1.
.\64tass.exe --cbm-prg -a src\loader.asm -L target\loader.lst -o target\loader
if errorlevel 1 exit /b 1

cd target
..\c1541.exe -format "simcity,01" d81 mega-simcity.d81
if errorlevel 1 exit /b 1
REM Disk-image order matters: loader is first so MEGA65 autoboot (F1/RUN
REM the first PRG) picks it up; then mega-simcity (trampoline target), then
REM overlays the main game streams during gameplay, then bulk tile data.
..\c1541.exe -attach mega-simcity.d81 -write loader loader
if errorlevel 1 exit /b 1
..\c1541.exe -attach mega-simcity.d81 -write mega-simcity mega-simcity
if errorlevel 1 exit /b 1
..\c1541.exe -attach mega-simcity.d81 -write tile-edit tile-edit
if errorlevel 1 exit /b 1
..\c1541.exe -attach mega-simcity.d81 -write ovr-disk ovr-disk
if errorlevel 1 exit /b 1
..\c1541.exe -attach mega-simcity.d81 -write ovr-inspect ovr-inspect
if errorlevel 1 exit /b 1
..\c1541.exe -attach mega-simcity.d81 -write tileset tileset
if errorlevel 1 exit /b 1
..\c1541.exe -attach mega-simcity.d81 -write uitiles uitiles
if errorlevel 1 exit /b 1
..\c1541.exe -attach mega-simcity.d81 -write palette palette
if errorlevel 1 exit /b 1
cd ..

echo Built target\mega-simcity.d81
