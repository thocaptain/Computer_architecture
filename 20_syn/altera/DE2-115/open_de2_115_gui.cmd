@echo off
if not defined QUARTUS_ROOTDIR set "QUARTUS_ROOTDIR=C:\altera\13.0sp1\quartus"
if not exist "%QUARTUS_ROOTDIR%\bin64\quartus.exe" (
  echo Quartus GUI not found: %QUARTUS_ROOTDIR%\bin64\quartus.exe
  exit /b 1
)
net use X: \\wsl.localhost\Ubuntu-20.04 /persistent:no >nul 2>&1
set "PROJECT_DIR=X:\home\lqhau\RISC-V-RV32i-master\20_syn\altera\DE2-115"
if not exist "%PROJECT_DIR%\DE2_115_single_cycle.qpf" (
  echo Quartus project not found: %PROJECT_DIR%\DE2_115_single_cycle.qpf
  exit /b 1
)
start "Quartus DE2-115" /D "%PROJECT_DIR%" "%QUARTUS_ROOTDIR%\bin64\quartus.exe" "%PROJECT_DIR%\DE2_115_single_cycle.qpf"
exit /b %ERRORLEVEL%
