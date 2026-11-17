#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateRange(1024, 65535)]
    [int]$WebPort = 5173
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot

function Require-Command([string]$Name, [string]$Hint) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Falta $Name. $Hint"
    }
}

function Assert-PortFree([int]$Port) {
    $listener = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    if ($listener) {
        throw "El puerto $Port esta ocupado. Deten la instancia anterior o elige otro WebPort para el frontend. No se cerrara ningun proceso automaticamente."
    }
}

function Quote-PowerShell([string]$Value) {
    return "'" + $Value.Replace("'", "''") + "'"
}

function Open-Terminal([string]$Title, [string]$Directory, [string]$Commands) {
    $command = '$Host.UI.RawUI.WindowTitle = ' + (Quote-PowerShell $Title) +
        [Environment]::NewLine + 'Set-Location -LiteralPath ' +
        (Quote-PowerShell $Directory) + [Environment]::NewLine + $Commands
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    Start-Process -FilePath 'powershell.exe' -ArgumentList @(
        '-NoExit', '-EncodedCommand', $encoded
    ) | Out-Null
}

Require-Command docker 'Instala y abre Docker Desktop.'
Require-Command java 'Instala Java JDK 21 y configura PATH.'
Require-Command flutter 'Instala Flutter estable y anade flutter/bin a PATH.'
Require-Command powershell.exe 'Este lanzador necesita Windows PowerShell.'

foreach ($relative in @('compose.yaml', 'backend/mvnw.cmd', 'mobile/pubspec.yaml')) {
    if (-not (Test-Path -LiteralPath (Join-Path $projectRoot $relative))) {
        throw "Falta $relative. Guarda este script en la raiz de la carpeta ParkU."
    }
}

$javaVersion = (& cmd.exe /d /c 'java -version 2>&1' | Out-String)
if ($javaVersion -notmatch 'version "21[.]') {
    throw "ParkU requiere JDK 21. Version detectada: $javaVersion"
}

& cmd.exe /d /c 'docker info >nul 2>&1'
if ($LASTEXITCODE -ne 0) {
    throw 'Docker Desktop no esta iniciado. Abre Docker Desktop y ejecuta de nuevo este script.'
}
& docker compose version
if ($LASTEXITCODE -ne 0) { throw 'Docker Compose no esta disponible.' }

Assert-PortFree 8000
Assert-PortFree $WebPort

Push-Location $projectRoot
try {
    Write-Host 'Iniciando PostgreSQL (sin borrar datos)...' -ForegroundColor Cyan
    & docker compose up -d --wait db
    if ($LASTEXITCODE -ne 0) {
        throw 'PostgreSQL no pudo arrancar. Revisa Docker Desktop y si el puerto 5432 esta ocupado.'
    }

    Push-Location (Join-Path $projectRoot 'mobile')
    try {
        Write-Host 'Preparando dependencias de Flutter...' -ForegroundColor Cyan
        & flutter pub get
        if ($LASTEXITCODE -ne 0) { throw 'flutter pub get fallo. Revisa el mensaje anterior.' }
    } finally {
        Pop-Location
    }

    $backendCommands = @'
$env:DB_URL = 'jdbc:postgresql://localhost:5432/parku'
$env:DB_USER = 'parku'
$env:PARKU_DEMO = 'true'
$env:PORT = '8000'
$env:SERVER_ADDRESS = '127.0.0.1'
if ([string]::IsNullOrWhiteSpace($env:DB_PASSWORD)) {
    $env:DB_PASSWORD = 'parku_local'
}
.\mvnw.cmd spring-boot:run
if ($LASTEXITCODE -ne 0) { Write-Host 'El backend fallo. Revisa esta ventana.' -ForegroundColor Red }
'@
    Open-Terminal 'ParkU - Backend' (Join-Path $projectRoot 'backend') $backendCommands

    Write-Host 'Esperando a que la API responda en el puerto 8000...' -ForegroundColor Cyan
    $ready = $false
    $deadline = (Get-Date).AddMinutes(5)
    while ((Get-Date) -lt $deadline) {
        try {
            Invoke-WebRequest -Uri 'http://127.0.0.1:8000/api/wallet/balance' -UseBasicParsing -TimeoutSec 3 | Out-Null
        } catch {
            $response = $_.Exception.Response
            if ($null -ne $response -and [int]$response.StatusCode -eq 401) {
                $ready = $true
                break
            }
        }
        Start-Sleep -Seconds 2
    }
    if (-not $ready) {
        throw 'La API no respondio como ParkU tras cinco minutos. Revisa la ventana ParkU - Backend.'
    }

    $frontendCommands = 'flutter run -d chrome --web-hostname=127.0.0.1 --web-port=' +
        $WebPort + ' --dart-define=API_BASE_URL=http://127.0.0.1:8000'
    Open-Terminal 'ParkU - Frontend' (Join-Path $projectRoot 'mobile') $frontendCommands

    Write-Host ''
    Write-Host 'Backend listo. Flutter abrira Chrome al terminar de compilar.' -ForegroundColor Green
    Write-Host "App: http://127.0.0.1:$WebPort"
    Write-Host 'API: http://127.0.0.1:8000'
    Write-Host ''
    Write-Host 'Cuenta local de Juan: juan.cardona@usantotomas.edu.co / pass123'
    Write-Host 'Taquilla: taquilla@usantotomas.edu.co / caja123'
    Write-Host 'Las cuentas demo existentes conservan sus datos y contrasenas.'
    Write-Host ''
    Write-Host 'Para detener: Ctrl+C en las ventanas de backend y frontend.'
    Write-Host 'Para detener solo la BD: docker compose stop db (desde ParkU).'
    Write-Host 'Si Chrome no abre, revisa la ventana ParkU - Frontend y ejecuta flutter doctor.'
} finally {
    Pop-Location
}
