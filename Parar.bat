@echo off
cd /d "%~dp0"
title Console NF-e - Parar
echo.
echo   Parando o Console NF-e...
echo   (seus dados sao PRESERVADOS: certificados, lotes e auditoria)
echo.
docker compose down
echo.
echo   Parado. Seus dados continuam salvos.
echo   Para usar de novo, clique em "Iniciar".
echo.
pause
