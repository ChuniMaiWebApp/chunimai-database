<#
  start-all.ps1  -  All-in-one: bring the Apple Music Downloader demo back ONLINE.

  Boots WSL, then runs the bring-up engine inside WSL which starts the Docker
  daemon, the whole prod stack (backend/frontend/supabase/redis/wrapper) and the
  Tailscale Funnel, and waits until this URL answers:

      https://novaseele.tail11872b.ts.net

  HOW TO RUN (from a PowerShell window in this folder):
      .\start-all.ps1
  If blocked by execution policy:
      powershell -ExecutionPolicy Bypass -File .\start-all.ps1

  Idempotent: safe to run any time (after a reboot, or to re-online the link).
  The actual logic lives in the WSL repo at /home/novaseele/dev/repo/bringup.sh
#>

$Distro = 'Ubuntu'
$Script = '/home/novaseele/dev/repo/bringup.sh'

Write-Host "Bringing up Apple Music Downloader via WSL ($Distro)..." -ForegroundColor Cyan

# 1) Boot the WSL distro (also makes systemd start docker + tailscaled).
wsl -d $Distro -u root -- /bin/true
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAILED] Cannot start WSL distro '$Distro'. Check installed distros with:  wsl -l -v" -ForegroundColor Red
    exit 1
}

# 1b) Keepalive. WSL2 shuts the distro down a few seconds after the last `wsl`
#     command exits, which takes Docker + the stack + the Funnel offline. Hold
#     the distro open with one hidden, detached `sleep infinity` process.
$keepalive = Get-CimInstance Win32_Process -Filter "Name='wsl.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like '*sleep infinity*' }
if (-not $keepalive) {
    Start-Process -WindowStyle Hidden -FilePath 'wsl.exe' `
        -ArgumentList '-d', $Distro, '-u', 'root', '--', 'sleep', 'infinity'
    Write-Host "Started WSL keepalive (keeps the distro online after this script exits)." -ForegroundColor DarkGray
} else {
    Write-Host "WSL keepalive already running." -ForegroundColor DarkGray
}

# 2) Run the bring-up engine as root (needed for systemctl + tailscale funnel).
wsl -d $Distro -u root -- bash $Script
$rc = $LASTEXITCODE

if ($rc -ne 0) {
    Write-Host "`n[!] Bring-up finished with exit code $rc (see messages above)." -ForegroundColor Yellow
}
exit $rc
