<#
  rebuild.ps1 - BUILD ONLY. Rebuild image(s) after code/Dockerfile changes.
                Does NOT start anything - run start-all.ps1 afterwards to launch.

  WHY separate: start-all.ps1 runs `up -d` (no build); this only builds the new
  image(s). After a SUCCESSFUL build, run start-all.ps1 to (re)start with it.

  USAGE:
    .\rebuild.ps1                           # build backend + frontend
    .\rebuild.ps1 backend                   # only backend
    .\rebuild.ps1 frontend                  # only frontend
    .\rebuild.ps1 wrapper                   # rebuild wrapper image (rare)
    .\rebuild.ps1 -NoCache                  # build without cache
    .\rebuild.ps1 backend -RecreateWrapper  # also drop am-wrapper so the NEXT start-all
                                            #   re-creates it (use when client.go wrapper settings changed)
    powershell -ExecutionPolicy Bypass -File .\rebuild.ps1
#>
param(
    [string[]]$Services = @('backend','frontend'),
    [switch]$RecreateWrapper,
    [switch]$NoCache
)

$Distro  = 'Ubuntu'
$EnvFile = '/home/novaseele/dev/repo/.env.prod'
$File    = '/home/novaseele/dev/repo/docker-compose.prod.yml'
# Common prefix passed to wsl: docker compose with absolute paths (no cd, no &&).
$base    = @('-d', $Distro, '--', 'docker', 'compose', '--env-file', $EnvFile, '-f', $File)

Write-Host "Rebuild (BUILD ONLY): $($Services -join ', ')$(if ($NoCache) { '  (no-cache)' })" -ForegroundColor Cyan

# --- Boot WSL + Docker (needed to build) ---
wsl -d $Distro -u root -- /bin/true
if ($LASTEXITCODE -ne 0) { Write-Host "[FAILED] Cannot start WSL distro '$Distro'." -ForegroundColor Red; exit 1 }
wsl -d $Distro -u root -- systemctl start docker

$ready = $false
for ($i = 0; $i -lt 20; $i++) { wsl -d $Distro -- docker info *> $null; if ($LASTEXITCODE -eq 0) { $ready = $true; break }; Start-Sleep -Seconds 1 }
if (-not $ready) { Write-Host "[FAILED] Docker daemon not ready." -ForegroundColor Red; exit 1 }

# --- Split wrapper from app services ---
$wantWrapper = ($Services -contains 'wrapper') -or ($Services -contains 'wrapper-image')
$app = @($Services | Where-Object { $_ -notin @('wrapper','wrapper-image') })

# --- Build wrapper image (uses the build-tools profile) ---
if ($wantWrapper) {
    Write-Host "==> building wrapper-image" -ForegroundColor Cyan
    $a = $base + @('--profile','build-tools','build'); if ($NoCache) { $a += '--no-cache' }; $a += 'wrapper-image'
    wsl @a
    if ($LASTEXITCODE -ne 0) { Write-Host "[FAILED] wrapper-image build." -ForegroundColor Red; exit 1 }
}

# --- Build app services ---
if ($app.Count -gt 0) {
    Write-Host "==> building: $($app -join ' ')" -ForegroundColor Cyan
    $a = $base + @('build'); if ($NoCache) { $a += '--no-cache' }; $a += $app
    wsl @a
    if ($LASTEXITCODE -ne 0) { Write-Host "[FAILED] build error - see output above (fix the code, then re-run)." -ForegroundColor Red; exit 1 }
}

# --- Optional: drop am-wrapper so the NEXT start-all re-creates it with new settings ---
if ($RecreateWrapper -or $wantWrapper) {
    Write-Host "==> removing am-wrapper (next start-all will re-create it)" -ForegroundColor Cyan
    wsl -d $Distro -- docker rm -f am-wrapper
}

Write-Host "`nBuild OK. Now run:  .\start-all.ps1   (to start / restart with the new image)" -ForegroundColor Green
