@echo off
setlocal

set REPO=C:\Users\pablo\lifecal-wallpaper

cd /d "%REPO%" || (
  echo No puedo entrar en %REPO%
  pause
  exit /b 1
)

REM Comprueba si hay cambios
for /f %%A in ('git status --porcelain') do set HASCHANGES=1

if not defined HASCHANGES (
  echo No hay cambios. Nada que subir.
  pause
  exit /b 0
)

echo Cambios detectados. Preparando commit...

git add -A

REM Mensaje automático con fecha y hora
for /f "tokens=1-3 delims=/" %%a in ("%date%") do set D=%%c-%%b-%%a
set T=%time:~0,2%%time:~3,2%
set T=%T: =0%
set MSG=Auto push %D%_%T%

git commit -m "%MSG%"

echo Haciendo push...
git push

echo Listo.
pause
