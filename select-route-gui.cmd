@echo off
setlocal EnableExtensions

set "HERE=%~dp0"
if "%HERE:~-1%"=="\" set "HERE=%HERE:~0,-1%"

cd /d "%HERE%" || (
  echo No puedo entrar en: %HERE%
  pause
  exit /b 1
)

echo Lanzando LifeCal GUI...
echo.

REM -STA es importante para Windows Forms
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%HERE%\select-route-gui.ps1"

set "ERR=%errorlevel%"
if not "%ERR%"=="0" (
  echo.
  echo ============================================================
  echo  La GUI ha fallado. Codigo de salida: %ERR%
  echo  Mira el log: %HERE%\lifecal_gui_error.log
  echo ============================================================
  echo.
  pause
)
endlocal
