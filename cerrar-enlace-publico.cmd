@echo off
setlocal
set "PARKU_SHARE_KEY=stop-only"
cd /d "%~dp0"
docker compose -p parku-public -f compose.public.yaml down --remove-orphans
if errorlevel 1 (
    echo No se pudo detener la vista publica. Revisa Docker Desktop.
    pause
    exit /b 1
)
echo Enlace publico cerrado. El backend y los datos de PostgreSQL se conservan.
pause
