# Script PowerShell để deploy Supabase lên WSL
# Author: Kiro AI Assistant
# Date: 2026-03-29

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deploy Supabase to WSL" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Kiểm tra WSL
Write-Host "Kiểm tra WSL..." -ForegroundColor Yellow
$wslStatus = wsl --list --verbose
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ WSL không khả dụng" -ForegroundColor Red
    exit 1
}
Write-Host "✓ WSL đang chạy" -ForegroundColor Green
Write-Host ""

# Copy setup script sang WSL
Write-Host "Copy setup script sang WSL..." -ForegroundColor Yellow
$setupScript = Get-Content "setup-wsl-docker.sh" -Raw
$setupScript | wsl -d Ubuntu bash -c "cat > /tmp/setup-wsl-docker.sh && chmod +x /tmp/setup-wsl-docker.sh"
Write-Host "✓ Đã copy setup script" -ForegroundColor Green
Write-Host ""

# Chạy setup script trong WSL
Write-Host "Chạy setup script trong WSL..." -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
wsl -d Ubuntu bash /tmp/setup-wsl-docker.sh

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "✓ Deploy thành công!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Supabase đang chạy trong WSL!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Để truy cập WSL và quản lý Supabase:" -ForegroundColor Yellow
    Write-Host "  wsl -d Ubuntu" -ForegroundColor White
    Write-Host "  cd /home/novaseele/dev/repo/ArtHub/supabase-local" -ForegroundColor White
    Write-Host ""
    Write-Host "Các lệnh hữu ích:" -ForegroundColor Yellow
    Write-Host "  docker compose ps        # Xem status" -ForegroundColor White
    Write-Host "  docker compose logs -f   # Xem logs" -ForegroundColor White
    Write-Host "  docker compose down      # Dừng services" -ForegroundColor White
    Write-Host "  docker compose up -d     # Khởi động lại" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "✗ Deploy thất bại" -ForegroundColor Red
    Write-Host "Kiểm tra logs ở trên để biết chi tiết" -ForegroundColor Yellow
    exit 1
}
