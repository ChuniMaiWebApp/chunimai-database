<#
  stop-all.ps1  -  Stop the Apple Music Downloader stack (opposite of start-all.ps1).

  Default: gracefully `docker compose down` (KEEPS data), turns the Tailscale
  Funnel off, and stops the WSL keepalive so the link goes offline cleanly.
  WSL/Docker may then idle-shut-down on their own.

  Add  -Shutdown  to also fully power off the WSL distro (wsl --shutdown).

  Run:  .\stop-all.ps1            (soft stop, keep WSL)
        .\stop-all.ps1 -Shutdown  (also shut the whole distro down)
        powershell -ExecutionPolicy Bypass -File .\stop-all.ps1
#>
param([switch]$Shutdown)

$Distro  = 'Ubuntu'
$Repo    = '/home/novaseele/dev/repo'
$Compose = 'docker compose --env-file .env.prod -f docker-compose.prod.yml'

Write-Host "Stopping Apple Music Downloader..." -ForegroundColor Cyan

# Is the distro running? (strip UTF-16 NULs from wsl.exe output so -match works)
$running = ((wsl.exe --list --running) -join ' ') -replace "`0", ''
if ($running -match $Distro) {
    Write-Host "==> docker compose down (keeping data)" -ForegroundColor Cyan
    wsl -d $Distro -- bash -lc "cd $Repo && $Compose down"

    Write-Host "==> Tailscale Funnel off" -ForegroundColor Cyan
    wsl -d $Distro -u root -- tailscale funnel --https=443 off 2>$null
} else {
    Write-Host "    Distro '$Distro' not running - stack already down." -ForegroundColor DarkGray
}

# Stop the WSL keepalive process(es) on the Windows side.
Write-Host "==> stopping WSL keepalive" -ForegroundColor Cyan
$ka = Get-CimInstance Win32_Process -Filter "Name='wsl.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like '*sleep infinity*' }
if ($ka) {
    $ka | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Write-Host "    keepalive stopped" -ForegroundColor Green
} else {
    Write-Host "    no keepalive running" -ForegroundColor DarkGray
}

if ($Shutdown) {
    Write-Host "==> wsl --shutdown (full stop of the distro)" -ForegroundColor Cyan
    wsl --shutdown
}

Write-Host "`nStopped. Run start-all.ps1 to bring it back online." -ForegroundColor Green
