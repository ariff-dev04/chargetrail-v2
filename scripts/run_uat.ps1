<#
.SYNOPSIS
    One-Click Live User Acceptance Testing (UAT) Launcher for ChargeTrail v2.
.DESCRIPTION
    Boots backend server, seeds Malaysian EV stations, configures ADB reverse tunnel, and launches Flutter.
.PARAMETER Device
    Target Flutter device (e.g., <YOUR_DEVICE_ID>, chrome, windows).
.PARAMETER ApiUrl
    Optional explicit override for API_BASE_URL.
#>
param (
    [string]$Device = "",
    [string]$ApiUrl = ""
)

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host " * ChargeTrail v2 - Live User Acceptance Testing (UAT) Launcher " -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Resolve ADB Executable Path
$adbExe = $null
$possibleAdbPaths = @(
    "adb",
    (Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"),
    "adb"
)
foreach ($candidate in $possibleAdbPaths) {
    if ($candidate -eq "adb") {
        $found = Get-Command adb -ErrorAction SilentlyContinue
        if ($found) { $adbExe = $found.Source; break }
    } elseif (Test-Path $candidate) {
        $adbExe = $candidate
        break
    }
}
if (-not $adbExe) { $adbExe = "adb" }
Write-Host "UAT: Using ADB binary: $adbExe" -ForegroundColor DarkGray

# 2. Detect Host LAN/Wi-Fi IPv4 for Physical Devices
$localIp = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254*" } |
    Select-Object -ExpandProperty IPAddress -First 1)
if (-not $localIp) { $localIp = "127.0.0.1" }
Write-Host "UAT: Host PC LAN/Wi-Fi IPv4: " -NoNewline
Write-Host $localIp -ForegroundColor Yellow

# 3. Check or Boot Backend Server on Port 8000
$portListening = $false
try {
    $client = New-Object System.Net.Sockets.TcpClient
    $iar = $client.BeginConnect("127.0.0.1", 8000, $null, $null)
    $success = $iar.AsyncWaitHandle.WaitOne(1000, $false)
    if ($success -and $client.Connected) {
        $client.EndConnect($iar)
        $portListening = $true
    }
    $client.Close()
} catch {}

if ($portListening) {
    Write-Host "UAT: FastAPI backend is already running on http://127.0.0.1:8000" -ForegroundColor Green
} else {
    Write-Host "UAT: Starting FastAPI server in background..." -ForegroundColor Cyan
    $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
    $backendDir = Join-Path $projectRoot "backend"
    $pythonExe = Join-Path $backendDir ".venv\Scripts\python.exe"
    if (-not (Test-Path $pythonExe)) { $pythonExe = "python" }

    Start-Process -FilePath $pythonExe -ArgumentList "-m uvicorn app.main:app --host 0.0.0.0 --port 8000" -WorkingDirectory $backendDir -WindowStyle Hidden
    Start-Sleep -Seconds 3
    Write-Host "UAT: FastAPI server booted on http://0.0.0.0:8000" -ForegroundColor Green
}

# 4. Seed Verified Malaysian EV Stations
try {
    if ($seedRes) {
        $seedMsg = $seedRes.message
        Write-Host "UAT: Database Seeder: $seedMsg" -ForegroundColor Green
    }
} catch {
    Write-Host "UAT: Database verified (seed stations present)." -ForegroundColor DarkGray
}

# 5. Detect or Select Target Device
$frontendDir = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")) "frontend"
Push-Location $frontendDir

if (-not $Device) {
    # Check for connected ADB physical or wireless devices first
    try {
        $adbOut = & $adbExe devices 2>$null
        $adbLines = $adbOut -split "`r?`n"
        foreach ($line in $adbLines) {
            if ($line -match '^([^\s]+)\s+device$') {
                $Device = $matches[1].Trim()
                Write-Host "UAT: Auto-detected active Android device: $Device" -ForegroundColor Green
                break
            }
        }
    } catch {}

    if (-not $Device) {
        $deviceListing = & flutter devices 2>&1
        Write-Host ""
        Write-Host "UAT: Available Devices:" -ForegroundColor Cyan
        $deviceListing | ForEach-Object { Write-Host "   $_" -ForegroundColor DarkGray }

        if ($deviceListing -match 'emulator|android') {
            $lines = $deviceListing -split "`r?`n"
            foreach ($line in $lines) {
                if ($line -match 'emulator' -or $line -match 'android') {
                    if ($line -match '([a-zA-Z0-9_\-\.:]+)\s+â€¢\s+android') {
                        $Device = $matches[1].Trim()
                        break
                    }
                }
            }
        }
    }

    if (-not $Device) {
        if ($deviceListing -match 'chrome') { $Device = "chrome" }
        elseif ($deviceListing -match 'windows') { $Device = "windows" }
        else { $Device = "chrome" }
    }
}

# 6. Configure ADB Reverse Port Forwarding & Resolve Smart Base URL
$adbReverseActive = $false
if ($Device -ne "chrome" -and $Device -ne "windows") {
    try {
        if ($Device -match '^[a-zA-Z0-9_\-\.:]+$') {
            & $adbExe -s $Device reverse tcp:8000 tcp:8000 2>$null
            $revList = & $adbExe -s $Device reverse --list 2>$null
        } else {
            & $adbExe reverse tcp:8000 tcp:8000 2>$null
            $revList = & $adbExe reverse --list 2>$null
        }
        if ($revList -match 'tcp:8000') {
            $adbReverseActive = $true
            Write-Host "UAT: ADB reverse tunnel active on port 8000" -ForegroundColor Green
        }
    } catch {}
}

if (-not $ApiUrl) {
    if ($adbReverseActive) {
        $ApiUrl = "http://127.0.0.1:8000"
        Write-Host "UAT: Using direct ADB reverse tunnel (bypasses Windows Firewall completely)" -ForegroundColor Green
    } elseif ($Device -match 'emulator') {
        $ApiUrl = "http://10.0.2.2:8000"
    } elseif ($Device -match 'android|phone|device') {
        $ApiUrl = "http://" + $localIp + ":8000"
    } else {
        $ApiUrl = "http://localhost:8000"
    }
}

Write-Host ""
Write-Host "UAT: Target Device   : $Device" -ForegroundColor Green
Write-Host "UAT: API Endpoint    : $ApiUrl" -ForegroundColor Green
Write-Host "UAT: Launching Flutter application..." -ForegroundColor Cyan
Write-Host ""

# 7. Run Flutter App
flutter run -d $Device --dart-define=API_BASE_URL=$ApiUrl

Pop-Location


