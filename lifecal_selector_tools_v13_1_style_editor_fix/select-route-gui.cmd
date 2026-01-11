@echo off
setlocal EnableExtensions

set "HERE=%~dp0"
if "%HERE:~-1%"=="\" set "HERE=%HERE:~0,-1%"

cd /d "%HERE%" || (
  echo No puedo entrar en: %HERE%
  pause
  exit /b 1
)

set "CONSOLE_LOG=%HERE%\lifecal_gui_console.log"
echo Lanzando LifeCal Selector (GUI)... > "%CONSOLE_LOG%"
echo (Este log captura la consola por si PowerShell peta antes de crear lifecal_gui_error.log) >> "%CONSOLE_LOG%"
echo. >> "%CONSOLE_LOG%"

powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%HERE%\select-route-gui.ps1" >> "%CONSOLE_LOG%" 2>&1

set "ERR=%errorlevel%"
if not "%ERR%"=="0" (
  echo.
  echo ============================================================
  echo  La GUI ha fallado. Codigo de salida: %ERR%
  echo  - Mira lifecal_gui_error.log (si existe)
  echo  - Si no existe, abre lifecal_gui_console.log
  echo ============================================================
  echo.
  pause
)
endlocal
