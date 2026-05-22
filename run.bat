@echo off
call build.bat
if errorlevel 1 exit /b 1

C:\Emulation\Mega65\xmega65.exe -8 C:\Users\scott\repos\mega-simcity\target\mega-simcity.d81 -hdosvirt true -autoload true
