@echo off
cd /d "%~dp0"
title Console NF-e - Iniciar
echo.
echo   Iniciando o Console NF-e...
echo   (a primeira vez pode demorar alguns minutos)
echo.
docker compose up -d
if errorlevel 1 (
  echo.
  echo   [ERRO] Nao consegui iniciar.
  echo   O Docker Desktop esta ABERTO e com o icone VERDE? Abra-o, espere ficar verde e tente de novo.
  echo.
  pause
  exit /b 1
)
echo.
echo   Preparando o sistema (aguarde)...
set "code="
set /a n=0
:wait
ping -n 3 127.0.0.1 >nul
for /f %%c in ('curl -s -o nul -w "%%{http_code}" http://localhost:3000/up 2^>nul') do set "code=%%c"
set /a n+=1
if "%code%"=="200" goto ready
if %n% GEQ 60 goto ready
goto wait
:ready
echo   Pronto. Abrindo o navegador em http://localhost:3000 ...
start "" "http://localhost:3000"
ping -n 4 127.0.0.1 >nul
