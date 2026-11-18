$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$compose = @('compose', '-p', 'parku-public', '-f', 'compose.public.yaml')
$gatewayStarted = $false
function Test-Backend {
    $socket = New-Object Net.Sockets.TcpClient
    try { $socket.Connect('127.0.0.1', 8000); return $true }
    catch { return $false }
    finally { $socket.Dispose() }
}
try {
    Get-Command docker, flutter -ErrorAction Stop | Out-Null
    & docker info 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Abre Docker Desktop antes de compartir.' }
    if (-not (Test-Backend)) {
        & cmd /c iniciar-parku.cmd
        if ($LASTEXITCODE -ne 0 -or -not (Test-Backend)) { throw 'El backend no esta listo. Revisa su ventana.' }
    }
    $socket = New-Object Net.Sockets.TcpClient
    try { $socket.Connect('127.0.0.1', 8080); throw 'El puerto 8080 esta ocupado. Cierra la vista publica anterior antes de continuar.' }
    catch [System.Net.Sockets.SocketException] { }
    finally { $socket.Dispose() }

    $bytes = New-Object byte[] 16
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($bytes)
    $rng.Dispose()
    $key = -join ($bytes | ForEach-Object { $_.ToString('x2') })
    $env:PARKU_SHARE_KEY = $key
    New-Item -ItemType Directory -Force '.local' | Out-Null
    Write-Host 'Compilando la version web para compartir...'
    Push-Location mobile
    try {
        & flutter pub get
        if ($LASTEXITCODE -ne 0) { throw 'No se pudieron resolver dependencias Flutter.' }
        & flutter build web "--base-href=/$key/" "--dart-define=API_BASE_URL=/$key"
        if ($LASTEXITCODE -ne 0) { throw 'No se pudo compilar la web.' }
    } finally { Pop-Location }
    & docker @compose up -d --wait gateway
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo iniciar el servidor publico local.' }
    $gatewayStarted = $true
    $response = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:8080/$key/"
    if ($response.StatusCode -ne 200) { throw 'No se pudo verificar la pagina local.' }
    Write-Host 'Creando enlace HTTPS temporal. Comparte SOLO el enlace completo que aparezca abajo.'
    Write-Host 'El enlace permite acceder a tu instancia local. Compartelo solo con las personas invitadas.'
    Write-Host 'Las cuentas y permisos de ParkU siguen siendo necesarios. Ctrl+C termina la vista publica.'
    $shown = $false
    # cloudflared writes informational messages to stderr. Merge native output
    # without treating these normal log lines as terminating PowerShell errors.
    $ErrorActionPreference = 'Continue'
    & docker @compose run --rm --no-deps tunnel 2>&1 | ForEach-Object {
        $line = "$_"
        if ($line -match 'https://[a-z0-9-]+\.trycloudflare\.com' -and -not $shown) {
            $url = "$($Matches[0])/$key/"
            $url | Set-Content -Encoding UTF8 '.local/enlace-publico.txt'
            Write-Host "`nENLACE PARKU: $url`n" -ForegroundColor Green
            try { Set-Clipboard -Value $url } catch { }
            $shown = $true
        }
        Write-Host $line
    }
    if ($LASTEXITCODE -ne 0) { throw 'El tunel se detuvo. Revisa los mensajes anteriores.' }
} catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
    exit 1
} finally {
    if ($gatewayStarted) {
        & docker @compose stop gateway
        Remove-Item '.local/enlace-publico.txt' -ErrorAction SilentlyContinue
    }
    Remove-Item Env:PARKU_SHARE_KEY -ErrorAction SilentlyContinue
}
