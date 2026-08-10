# =====================================================================
# kill-ports.ps1 — Free every port declared by the AppleMusicDownloader
# pass-4 stack, so the next `start` is a clean slate.
#
# Order of operations:
#   1. docker compose down on each containerized stack
#      (supabase-local, redis) — releases their port mappings cleanly.
#   2. Stop the lone wrapper container (am-wrapper) — managed outside compose.
#   3. Fall back to PID-based kill for any process still LISTENING on a
#      declared port (Vite dev, Go backend, stray instances).
#
# Source of truth for the port list:
#   codex-process/21-pass4-roadmap.md §Port allocation
#
# Usage (PowerShell):
#   cd D:\Work\AppleMusicDownloader
#   .\kill-ports.ps1
#
# This script is idempotent — running it twice is safe and quiet.
# =====================================================================

$ErrorActionPreference = 'Continue'

# Allocated host ports for this repo. Keep in sync with doc 21.
$ports = @(
  3000,   # Supabase Studio
  3001,   # PostgREST
  4000,   # Supabase Realtime
  5000,   # Supabase Storage
  5173,   # Vite frontend dev
  5432,   # Postgres
  5540,   # RedisInsight web UI
  6379,   # Redis
  8181,   # Supabase Meta
  8088,   # Frontend nginx (Docker prod)
  8090,   # Backend Go (dev)
  8095,   # Kong gateway
  9999,   # GoTrue Auth
  10020,  # Wrapper decrypt
  20020,  # Wrapper m3u8
  30020   # Wrapper account
)

function Write-Step($msg)    { Write-Host "» $msg" -ForegroundColor Cyan }
function Write-Ok($msg)      { Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Skip($msg)    { Write-Host "  · $msg" -ForegroundColor DarkGray }
function Write-Warn($msg)    { Write-Host "  ! $msg" -ForegroundColor Yellow }

# ---------- 1. Compose stacks ----------------------------------------------

function Compose-Down($dir, $label) {
  Write-Step "$label — docker compose down ($dir)"
  if (-not (Test-Path (Join-Path $dir 'docker-compose.yml'))) {
    Write-Skip "no docker-compose.yml at $dir, skipping"
    return
  }
  Push-Location $dir
  try {
    docker compose down 2>&1 | ForEach-Object {
      if ($_ -match 'Removing|Stopping|Removed|Stopped') {
        Write-Ok $_.ToString().Trim()
      } elseif ($_ -match 'no such|not running|No containers') {
        Write-Skip $_.ToString().Trim()
      }
    }
  } catch {
    Write-Warn "docker compose down failed: $($_.Exception.Message)"
  } finally {
    Pop-Location
  }
}

Compose-Down (Join-Path $PSScriptRoot 'supabase-local') 'Supabase'
Compose-Down (Join-Path $PSScriptRoot 'redis')          'Redis'

# ---------- 2. Lone wrapper container --------------------------------------

Write-Step 'Wrapper container (am-wrapper)'
$wrapperRunning = docker ps --filter 'name=^am-wrapper$' --format '{{.Names}}' 2>$null
if ($wrapperRunning -eq 'am-wrapper') {
  docker stop am-wrapper 2>&1 | Out-Null
  Write-Ok 'am-wrapper stopped'
} else {
  Write-Skip 'am-wrapper not running'
}

# ---------- 3. PID kill for any remaining listener -------------------------

Write-Step 'PID kill for remaining listeners'

function Get-ListeningPIDs($port) {
  # netstat output columns: Proto Local Foreign State PID
  # We only kill TCP LISTENING (UDP usually not relevant here).
  $rows = netstat -ano -p tcp | Select-String -Pattern (":$port\s") | Where-Object { $_ -match 'LISTENING' }
  $pids = @{}
  foreach ($row in $rows) {
    $parts = $row.ToString().Trim() -split '\s+'
    if ($parts.Length -ge 5) {
      $candidate = $parts[$parts.Length - 1]
      if ($candidate -match '^\d+$' -and [int]$candidate -ne 0) {
        $pids[[int]$candidate] = $true
      }
    }
  }
  return $pids.Keys
}

function Resolve-ProcessName($processId) {
  try {
    $p = Get-Process -Id $processId -ErrorAction Stop
    return "$($p.ProcessName) (PID $processId)"
  } catch {
    return "PID $processId"
  }
}

$anyKilled = $false
foreach ($port in $ports) {
  $pids = Get-ListeningPIDs $port
  if (-not $pids -or $pids.Count -eq 0) {
    Write-Skip "$port — free"
    continue
  }
  foreach ($targetPid in $pids) {
    # Refuse to touch System Idle (0) and System (4); netstat sometimes
    # attributes the listener to System on Windows port reservation.
    if ($targetPid -le 4) {
      Write-Warn "$port — held by System (PID $targetPid); cannot kill"
      continue
    }
    $label = Resolve-ProcessName $targetPid
    try {
      Stop-Process -Id $targetPid -Force -ErrorAction Stop
      Write-Ok "$port — killed $label"
      $anyKilled = $true
    } catch {
      Write-Warn "$port — failed to kill $label : $($_.Exception.Message)"
    }
  }
}

if (-not $anyKilled) {
  Write-Host ''
  Write-Host 'All ports clean.' -ForegroundColor Green
} else {
  Write-Host ''
  Write-Host 'Done. Re-run with .\start-all (or manual sequence) to bring the stack back up.' -ForegroundColor Green
}
