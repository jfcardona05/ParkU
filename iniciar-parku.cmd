@echo off
setlocal
title ParkU - Inicio rapido
cd /d "%~dp0"

if not exist "compose.yaml" goto :structure_error
if not exist "backend\mvnw.cmd" goto :structure_error
if not exist "mobile\pubspec.yaml" goto :structure_error

where docker >nul 2>&1
if errorlevel 1 (
    echo ERROR: No se encontro Docker. Instala Docker Desktop y vuelve a intentarlo.
    goto :failed
)
where flutter >nul 2>&1
if errorlevel 1 (
    echo ERROR: No se encontro Flutter en PATH. Reabre la terminal tras instalarlo.
    goto :failed
)

if defined JAVA_HOME (
    if not exist "%JAVA_HOME%\bin\java.exe" set "JAVA_HOME="
)
if not defined JAVA_HOME (
    for /d %%J in ("%ProgramFiles%\Eclipse Adoptium\jdk-21*") do (
        if exist "%%~fJ\bin\java.exe" set "JAVA_HOME=%%~fJ"
    )
)
if defined JAVA_HOME set "PATH=%JAVA_HOME%\bin;%PATH%"
where java >nul 2>&1
if errorlevel 1 (
    echo ERROR: Instala Java 21 o configura JAVA_HOME antes de continuar.
    goto :failed
)

docker info >nul 2>&1
if errorlevel 1 (
    echo ERROR: Abre Docker Desktop y espera a que indique Engine running.
    echo Luego vuelve a abrir este archivo.
    goto :failed
)

powershell -NoProfile -Command "$c=New-Object Net.Sockets.TcpClient; try{$c.Connect('127.0.0.1',8000); exit 1}catch{exit 0}finally{$c.Dispose()}"
if errorlevel 1 (
    echo ERROR: El puerto 8000 ya esta ocupado.
    echo Si ParkU ya esta abierto, usa sus ventanas. Si no, revisa ese proceso.
    goto :failed
)

if not defined DB_URL set "DB_URL=jdbc:postgresql://127.0.0.1:5432/parku"
if not defined DB_USER set "DB_USER=parku"
if not defined DB_PASSWORD set "DB_PASSWORD=parku_local"
if not defined PARKU_DEMO set "PARKU_DEMO=true"

echo Iniciando PostgreSQL y esperando su estado healthy...
docker compose up -d --wait --wait-timeout 120 db
if errorlevel 1 (
    echo ERROR: No se pudo iniciar PostgreSQL. Revisa Docker y el puerto 5432.
    echo No se han borrado contenedores ni volumenes.
    goto :failed
)

echo Iniciando backend con Java:
java -version
start "ParkU - Backend" /D "%~dp0backend" cmd /k "mvnw.cmd spring-boot:run"
if errorlevel 1 goto :failed

echo Esperando al backend en el puerto 8000, hasta 5 minutos...
powershell -NoProfile -Command "$ready=$false; for($i=0;$i -lt 300;$i++){ $c=New-Object Net.Sockets.TcpClient; try{$c.Connect('127.0.0.1',8000); $ready=$true; break}catch{Start-Sleep -Seconds 1}finally{$c.Dispose()} }; if(-not $ready){exit 1}"
if errorlevel 1 (
    echo ERROR: El backend no inicio a tiempo. Revisa su ventana antes de reintentar.
    goto :failed
)

echo Iniciando Flutter. Chrome se abrira al terminar la compilacion.
start "ParkU - Frontend" /D "%~dp0mobile" cmd /k "flutter pub get && flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000"
if errorlevel 1 goto :failed
echo Listo. Deja Docker y las ventanas Backend y Frontend abiertas.
exit /b 0

:structure_error
echo ERROR: Este archivo debe estar junto a compose.yaml, backend y mobile.
:failed
pause
exit /b 1
