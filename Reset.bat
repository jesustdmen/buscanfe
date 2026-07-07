@echo off
cd /d "%~dp0"
title Console NF-e - RESET (apaga tudo)
echo ============================================================
echo    ATENCAO -- RESET COMPLETO (acao IRREVERSIVEL)
echo ============================================================
echo.
echo   Isto APAGA TUDO de forma permanente:
echo     - todos os certificados cadastrados
echo     - todos os lotes e os XML baixados
echo     - toda a trilha de auditoria
echo     - o usuario administrador
echo.
echo   Depois do reset, a proxima abertura vai pedir para criar um novo administrador.
echo   Esta acao NAO pode ser desfeita.
echo.
set "CONF="
set /p "CONF=Para confirmar, digite  RESETAR  e tecle Enter: "
if /I not "%CONF%"=="RESETAR" (
  echo.
  echo   Cancelado. Nada foi apagado.
  echo.
  pause
  exit /b 0
)
echo.
echo   Apagando tudo...
docker compose down -v
del /q "storage\xml\*.xml" >nul 2>&1
echo.
echo   Reset concluido. Na proxima vez que iniciar, o sistema vai pedir um novo administrador.
echo.
pause
