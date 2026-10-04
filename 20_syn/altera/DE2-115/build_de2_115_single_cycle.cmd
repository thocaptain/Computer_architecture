@echo off
pushd "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "build_de2_115_single_cycle.ps1" %*
set "BUILD_EXIT=%ERRORLEVEL%"
popd
exit /b %BUILD_EXIT%