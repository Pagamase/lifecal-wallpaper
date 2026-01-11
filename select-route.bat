@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM  LifeCal - Selector de route.tsx
REM  - Copia una versión backup a app\year\route.tsx
REM  - Opcional: git add/commit/push
REM ============================================================

set "REPO=%~dp0"
REM Quita barra final si existe
if "%REPO:~-1%"=="\" set "REPO=%REPO:~0,-1%"

REM Detecta carpeta de backups
set "BACKUPDIR=%REPO%\lifecal_route_backups"
if not exist "%BACKUPDIR%" (
  set "BACKUPDIR=%REPO%\route_backups"
)

if not exist "%BACKUPDIR%" (
  echo No encuentro la carpeta de backups.
  echo Crea una de estas en la raiz del repo:
  echo   - lifecal_route_backups
  echo   - route_backups
  echo.
  echo Ruta esperada del repo:
  echo   %REPO%
  pause
  exit /b 1
)

set "TARGET=%REPO%\app\year\route.tsx"
if not exist "%REPO%\app\year" (
  echo No encuentro %REPO%\app\year
  echo Asegurate de ejecutar esto en la raiz del repo lifecal-wallpaper.
  pause
  exit /b 1
)

REM Lista fija (orden bonito). Si faltan, lo avisamos.
set "F1=01_route_year_19_and_birthdays_queryparam.tsx"
set "F2=02_route_year_weekend_blue_variant.tsx"
set "F3=03_route_year_sat_dark_sun_red.tsx"
set "F4=04_route_year_sat_light_sun_red.tsx"
set "F5=05_route_year_sat_light_sun_red_footer_glued.tsx"
set "F6=06_route_year_progress_bar.tsx"
set "F7=07_route_year_progress_bar_birthdays_red_ring.tsx"
set "F8=08_route_year_progress_bar_birthdays_today_halo.tsx"

:menu
cls
echo ============================================================
echo  LifeCal - Selector de versiones (route.tsx)
echo ============================================================
echo Repo:      %REPO%
echo Backups:   %BACKUPDIR%
echo Target:    %TARGET%
echo ------------------------------------------------------------
echo  1) %F1%
echo  2) %F2%
echo  3) %F3%
echo  4) %F4%
echo  5) %F5%
echo  6) %F6%
echo  7) %F7%
echo  8) %F8%
echo  Q) Salir
echo ------------------------------------------------------------
choice /C 12345678Q /N /M "Elige una opcion: "
set "sel=%errorlevel%"

if "%sel%"=="9" goto :eof
if "%sel%"=="1" set "FILE=%F1%"
if "%sel%"=="2" set "FILE=%F2%"
if "%sel%"=="3" set "FILE=%F3%"
if "%sel%"=="4" set "FILE=%F4%"
if "%sel%"=="5" set "FILE=%F5%"
if "%sel%"=="6" set "FILE=%F6%"
if "%sel%"=="7" set "FILE=%F7%"
if "%sel%"=="8" set "FILE=%F8%"

set "SRC=%BACKUPDIR%\%FILE%"

if not exist "%SRC%" (
  echo.
  echo No existe el archivo:
  echo   %SRC%
  echo Comprueba que el backup esta bien descomprimido.
  pause
  goto :menu
)

echo.
echo Copiando:
echo   %SRC%
echo a:
echo   %TARGET%
copy /Y "%SRC%" "%TARGET%" >nul
if errorlevel 1 (
  echo Error copiando el archivo.
  pause
  goto :menu
)

echo OK. Ya tienes esa version activa.
echo.

REM Pregunta si quiere push automatico
choice /C SN /N /M "Quieres hacer git add/commit/push ahora? (S/N): "
if errorlevel 2 goto :done

REM Push
cd /d "%REPO%" || (
  echo No puedo entrar en %REPO%
  pause
  goto :menu
)

REM Si no hay cambios, no hace nada
set "HASCHANGES="
for /f %%A in ('git status --porcelain') do (
  set HASCHANGES=1
  goto :breakloop
)
:breakloop

if not defined HASCHANGES (
  echo No hay cambios en git. Nada que subir.
  pause
  goto :menu
)

git add -A

REM Mensaje con fecha/hora
for /f "tokens=1-3 delims=/" %%a in ("%date%") do set D=%%c-%%b-%%a
set T=%time:~0,2%%time:~3,2%
set T=%T: =0%
set MSG=Switch route %FILE% %D%_%T%

git commit -m "%MSG%"
git push

echo.
echo Push hecho.
pause
goto :menu

:done
pause
goto :menu
