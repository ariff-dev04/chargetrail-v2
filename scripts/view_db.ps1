<#
.SYNOPSIS
    ChargeTrail v2 Live Database & OSM Import Inspector.
.DESCRIPTION
    Queries the live backend (or local SQLite) and prints all persisted stations with source tags.
#>

$ErrorActionPreference = "SilentlyContinue"

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host " * ChargeTrail v2 - Live Database & Station Inventory Inspector   " -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

$stations = $null
$metrics = $null

try {
    $metrics = Invoke-RestMethod -Uri "http://127.0.0.1:8000/api/v1/metrics" -TimeoutSec 2
    $stations = Invoke-RestMethod -Uri "http://127.0.0.1:8000/api/v1/stations" -TimeoutSec 2
} catch {}

if ($metrics) {
    Write-Host "Backend Status      : $($metrics.status) (Uptime: $($metrics.uptime_seconds)s)" -ForegroundColor Green
    Write-Host "Total Requests      : $($metrics.total_requests) (Avg Latency: $($metrics.average_latency_ms) ms)" -ForegroundColor Gray
    Write-Host "Verified Stations   : $($metrics.verified_stations_count)" -ForegroundColor Yellow
    Write-Host "Pending Moderation  : $($metrics.pending_stations_count)" -ForegroundColor DarkYellow
    Write-Host ""
    Write-Host "Inventory by Source :" -ForegroundColor Cyan
    if ($metrics.stations_by_source) {
        $metrics.stations_by_source.PSObject.Properties | ForEach-Object {
            Write-Host "  - $($_.Name): $($_.Value)" -ForegroundColor White
        }
    }
    Write-Host ""
} else {
    Write-Host "Notice: Live backend on :8000 not responding. Inspecting local SQLite directly..." -ForegroundColor Yellow
    $pyCmd = "
import sqlite3, os
p = 'backend/chargetrail_local.db'
if os.path.exists(p):
    conn = sqlite3.connect(p)
    cur = conn.cursor()
    cur.execute('SELECT source, count(*) FROM charging_stations GROUP BY source')
    print('SQLite Inventory by Source:')
    for r in cur.fetchall():
        print(f'  - {r[0]}: {r[1]}')
    cur.execute('SELECT name, city, source, max_power_kw, is_verified FROM charging_stations')
    rows = cur.fetchall()
    print(f'Total Saved Stations: {len(rows)}')
"
    python -c $pyCmd
}

if ($stations -and $stations.Count -gt 0) {
    Write-Host "Persisted Station Records in Database ($($stations.Count) total):" -ForegroundColor Cyan
    $tableData = $stations | Select-Object @{N="Name";E={$_.name}},
                                           @{N="City";E={$_.city}},
                                           @{N="Source";E={$_.source}},
                                           @{N="Max kW";E={$_.max_power_kw}},
                                           @{N="Verified";E={$_.is_verified}}
    $tableData | Format-Table -AutoSize
} elseif (-not $metrics) {
    Write-Host ""
    Write-Host "Tip: Run `powershell -ExecutionPolicy Bypass -File scripts/run_uat.ps1` to boot live server." -ForegroundColor DarkGray
}


