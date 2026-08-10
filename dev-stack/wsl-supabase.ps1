# Script PowerShell để quản lý Supabase trong WSL
# Author: Kiro AI Assistant
# Date: 2026-03-29

param(
    [Parameter(Position=0)]
    [ValidateSet("start", "stop", "restart", "status", "logs", "shell", "health")]
    [string]$Command = "status"
)

$WSL_DIST = "Ubuntu"
$PROJECT_PATH = "/home/novaseele/dev/repo/ArtHub/supabase-local"

function Show-Usage {
    Write-Host "Sử dụng: .\wsl-supabase.ps1 <command>" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor Yellow
    Write-Host "  start    - Khởi động Supabase" -ForegroundColor White
    Write-Host "  stop     - Dừng Supabase" -ForegroundColor White
    Write-Host "  restart  - Khởi động lại Supabase" -ForegroundColor White
    Write-Host "  status   - Xem trạng thái containers" -ForegroundColor White
    Write-Host "  logs     - Xem logs (real-time)" -ForegroundColor White
    Write-Host "  health   - Kiểm tra health của services" -ForegroundColor White
    Write-Host "  shell    - Mở shell trong WSL tại project directory" -ForegroundColor White
    Write-Host ""
}

function Invoke-WSLCommand {
    param([string]$Cmd)
    wsl -d $WSL_DIST bash -c "cd $PROJECT_PATH && $Cmd"
}

switch ($Command) {
    "start" {
        Write-Host "Khởi động Supabase trong WSL..." -ForegroundColor Yellow
        Invoke-WSLCommand "sudo service docker start && docker compose up -d"
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Supabase đã được khởi động" -ForegroundColor Green
            Write-Host ""
            Write-Host "Truy cập:" -ForegroundColor Yellow
            Write-Host "  - Studio: http://localhost:3000" -ForegroundColor White
            Write-Host "  - API: http://localhost:8000" -ForegroundColor White
            Write-Host "  - PostgreSQL: localhost:5432" -ForegroundColor White
        } else {
            Write-Host "✗ Lỗi khi khởi động Supabase" -ForegroundColor Red
        }
    }
    
    "stop" {
        Write-Host "Dừng Supabase trong WSL..." -ForegroundColor Yellow
        Invoke-WSLCommand "docker compose down"
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Supabase đã được dừng" -ForegroundColor Green
        } else {
            Write-Host "✗ Lỗi khi dừng Supabase" -ForegroundColor Red
        }
    }
    
    "restart" {
        Write-Host "Khởi động lại Supabase trong WSL..." -ForegroundColor Yellow
        Invoke-WSLCommand "docker compose restart"
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Supabase đã được khởi động lại" -ForegroundColor Green
        } else {
            Write-Host "✗ Lỗi khi khởi động lại Supabase" -ForegroundColor Red
        }
    }
    
    "status" {
        Write-Host "Trạng thái Supabase trong WSL:" -ForegroundColor Yellow
        Write-Host ""
        Invoke-WSLCommand "docker compose ps"
    }
    
    "logs" {
        Write-Host "Logs Supabase (Ctrl+C để thoát):" -ForegroundColor Yellow
        Write-Host ""
        Invoke-WSLCommand "docker compose logs -f"
    }
    
    "health" {
        Write-Host "Kiểm tra health của Supabase services..." -ForegroundColor Yellow
        Write-Host ""
        
        # Kiểm tra Docker service
        Write-Host "Docker Service:" -ForegroundColor Cyan
        Invoke-WSLCommand "sudo service docker status | grep -o 'running\|stopped'"
        
        Write-Host ""
        Write-Host "Containers:" -ForegroundColor Cyan
        Invoke-WSLCommand "docker compose ps --format 'table {{.Name}}\t{{.Status}}'"
        
        Write-Host ""
        Write-Host "Ports:" -ForegroundColor Cyan
        Write-Host "  - Studio (3000): " -NoNewline
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:3000" -TimeoutSec 2 -UseBasicParsing -ErrorAction SilentlyContinue
            Write-Host "✓ OK" -ForegroundColor Green
        } catch {
            Write-Host "✗ Not accessible" -ForegroundColor Red
        }
        
        Write-Host "  - API (8000): " -NoNewline
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:8000" -TimeoutSec 2 -UseBasicParsing -ErrorAction SilentlyContinue
            Write-Host "✓ OK" -ForegroundColor Green
        } catch {
            Write-Host "✗ Not accessible" -ForegroundColor Red
        }
        
        Write-Host "  - PostgreSQL (5432): " -NoNewline
        $pgTest = Invoke-WSLCommand "timeout 2 bash -c 'cat < /dev/null > /dev/tcp/localhost/5432' 2>/dev/null && echo 'OK' || echo 'FAIL'"
        if ($pgTest -match "OK") {
            Write-Host "✓ OK" -ForegroundColor Green
        } else {
            Write-Host "✗ Not accessible" -ForegroundColor Red
        }
    }
    
    "shell" {
        Write-Host "Mở shell trong WSL tại project directory..." -ForegroundColor Yellow
        Write-Host "Gõ 'exit' để thoát" -ForegroundColor Gray
        Write-Host ""
        wsl -d $WSL_DIST bash -c "cd $PROJECT_PATH && exec bash"
    }
    
    default {
        Show-Usage
    }
}
