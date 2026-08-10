# Redis Local Management Script for Windows PowerShell
# Usage: .\redis-local.ps1 [start|stop|restart|status|monitor|logs]

param(
    [Parameter(Position=0)]
    [ValidateSet('start','stop','restart','status','monitor','logs','cli','info','ping','data','keys','get','view','help')]
    [string]$Command = 'help',
    
    [Parameter(Position=1)]
    [string]$Arg1 = ''
)

function Get-RedisKeys {
    param([string]$Pattern = '*')
    Write-Host "Fetching Redis keys..." -ForegroundColor Yellow
    Write-Host ""
    if ($Pattern -eq '*') {
        $keys = wsl redis-cli --scan
    } else {
        $keys = wsl redis-cli --scan --pattern $Pattern
    }
    $keyCount = ($keys | Measure-Object).Count
    Write-Host "Found $keyCount keys" -ForegroundColor Cyan
    Write-Host ""
    $keys | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }
}

function Get-RedisKeyValue {
    param([string]$Key)
    if ([string]::IsNullOrEmpty($Key)) {
        Write-Host "Error: Please provide a key name" -ForegroundColor Red
        Write-Host "Usage: .\redis-local.ps1 get <key>" -ForegroundColor Yellow
        return
    }
    
    Write-Host "Getting value for key: $Key" -ForegroundColor Yellow
    Write-Host ""
    $value = wsl redis-cli GET $Key
    $ttl = wsl redis-cli TTL $Key
    
    Write-Host "Key: " -NoNewline -ForegroundColor Cyan
    Write-Host $Key -ForegroundColor White
    Write-Host "Value: " -NoNewline -ForegroundColor Cyan
    Write-Host $value -ForegroundColor White
    Write-Host "TTL: " -NoNewline -ForegroundColor Cyan
    if ($ttl -eq "-1") {
        Write-Host "No expiration" -ForegroundColor Green
    } elseif ($ttl -eq "-2") {
        Write-Host "Key does not exist" -ForegroundColor Red
    } else {
        Write-Host "$ttl seconds" -ForegroundColor Yellow
    }
}

function Show-RedisData {
    Write-Host ""
    Write-Host "Redis Data Overview" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor Cyan
    Write-Host ""
    
    # Get all keys
    $allKeys = wsl redis-cli --scan
    $totalCount = ($allKeys | Measure-Object).Count
    Write-Host "Total Keys: $totalCount" -ForegroundColor Green
    Write-Host ""
    
    # Group by pattern
    $patterns = @(
        @{Name="Rate Limiting"; Pattern="rate_limit:*"},
        @{Name="Blocked IPs"; Pattern="blocked_ip:*"},
        @{Name="Image Tokens"; Pattern="image_token:*"},
        @{Name="Processed Images"; Pattern="image:processed:*"},
        @{Name="Risk Scores"; Pattern="risk_score:*"},
        @{Name="Test Keys"; Pattern="test:*"}
    )
    
    foreach ($p in $patterns) {
        $keys = wsl redis-cli --scan --pattern $p.Pattern
        $count = ($keys | Measure-Object).Count
        if ($count -gt 0) {
            Write-Host "$($p.Name): " -NoNewline -ForegroundColor Yellow
            Write-Host "$count keys" -ForegroundColor White
        }
    }
    
    Write-Host ""
    Write-Host "Quick Commands:" -ForegroundColor Cyan
    Write-Host "  .\redis\redis-local.ps1 keys              - List all keys" -ForegroundColor White
    Write-Host "  .\redis\redis-local.ps1 keys rate_limit:* - List keys by pattern" -ForegroundColor White
    Write-Host "  .\redis\redis-local.ps1 get <key>         - Get key value" -ForegroundColor White
    Write-Host "  .\redis\redis-local.ps1 view              - View formatted data" -ForegroundColor White
    Write-Host ""
}

function Show-RedisDataFormatted {
    Write-Host "Opening formatted Redis data viewer..." -ForegroundColor Yellow
    Write-Host ""
    if (Test-Path "nestjs-backend/view-redis-data.js") {
        Push-Location nestjs-backend
        node view-redis-data.js
        Pop-Location
    } else {
        Write-Host "Error: view-redis-data.js not found" -ForegroundColor Red
        Write-Host "Please run from the project root directory" -ForegroundColor Yellow
    }
}

function Start-Redis {
    $ping = wsl redis-cli ping 2>$null
    if ($ping -match "PONG") {
        Write-Host "[OK] Redis server is already running and responding on port 6379" -ForegroundColor Green
        Write-Host "  - Host: localhost" -ForegroundColor Cyan
        Write-Host "  - Port: 6379" -ForegroundColor Cyan
        return
    }

    Write-Host "Starting Redis server..." -ForegroundColor Yellow
    wsl sudo service redis-server start
    Start-Sleep -Seconds 2
    
    $status = wsl sudo service redis-server status
    if ($status -match "is running") {
        Write-Host "[OK] Redis server started successfully" -ForegroundColor Green
        Write-Host "  - Host: localhost" -ForegroundColor Cyan
        Write-Host "  - Port: 6379" -ForegroundColor Cyan
        Write-Host "  - Monitor: " -NoNewline -ForegroundColor Cyan
        Write-Host '.\redis-local.ps1 monitor' -ForegroundColor White
        Write-Host "  - CLI: " -NoNewline -ForegroundColor Cyan
        Write-Host '.\redis-local.ps1 cli' -ForegroundColor White
    } else {
        Write-Host "[ERR] Failed to start Redis server" -ForegroundColor Red
        exit 1
    }
}

function Stop-Redis {
    Write-Host "Stopping Redis server..." -ForegroundColor Yellow
    wsl sudo service redis-server stop
    Start-Sleep -Seconds 1
    Write-Host "[OK] Redis server stopped" -ForegroundColor Green
}

function Restart-Redis {
    Write-Host "Restarting Redis server..." -ForegroundColor Yellow
    wsl sudo service redis-server restart
    Start-Sleep -Seconds 2
    
    $status = wsl sudo service redis-server status
    if ($status -match "is running") {
        Write-Host "[OK] Redis server restarted successfully" -ForegroundColor Green
    } else {
        Write-Host "[ERR] Failed to restart Redis server" -ForegroundColor Red
        exit 1
    }
}

function Get-RedisStatus {
    wsl sudo service redis-server status
}

function Start-RedisMonitor {
    Write-Host "Starting Redis monitor (Ctrl+C to exit)..." -ForegroundColor Yellow
    Write-Host ""
    wsl redis-cli monitor
}

function Get-RedisLogs {
    Write-Host "Viewing Redis logs (Ctrl+C to exit)..." -ForegroundColor Yellow
    Write-Host ""
    wsl sudo journalctl -u redis-server -f
}

function Start-RedisCli {
    Write-Host "Opening Redis CLI (type 'exit' to quit)..." -ForegroundColor Yellow
    Write-Host ""
    wsl redis-cli
}

function Get-RedisInfo {
    wsl redis-cli info
}

function Test-RedisConnection {
    Write-Host "Testing Redis connection..." -ForegroundColor Yellow
    $result = wsl redis-cli ping
    if ($result -eq "PONG") {
        Write-Host "[OK] Redis is responding: $result" -ForegroundColor Green
    } else {
        Write-Host "[ERR] Redis is not responding" -ForegroundColor Red
    }
}

function Show-Help {
    Write-Host ""
    Write-Host "Redis Local Management" -ForegroundColor Cyan
    Write-Host "======================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: " -NoNewline
    Write-Host ".\redis\redis-local.ps1 [command] [args]" -ForegroundColor White
    Write-Host ""
    Write-Host "Server Commands:" -ForegroundColor Yellow
    Write-Host "  start    " -NoNewline -ForegroundColor Green
    Write-Host "- Start Redis server"
    Write-Host "  stop     " -NoNewline -ForegroundColor Green
    Write-Host "- Stop Redis server"
    Write-Host "  restart  " -NoNewline -ForegroundColor Green
    Write-Host "- Restart Redis server"
    Write-Host "  status   " -NoNewline -ForegroundColor Green
    Write-Host "- Check Redis server status"
    Write-Host "  ping     " -NoNewline -ForegroundColor Green
    Write-Host "- Test Redis connection"
    Write-Host ""
    Write-Host "Data Commands:" -ForegroundColor Yellow
    Write-Host "  data     " -NoNewline -ForegroundColor Green
    Write-Host "- Show Redis data overview"
    Write-Host "  keys     " -NoNewline -ForegroundColor Green
    Write-Host "[pattern] - List all keys (or by pattern)"
    Write-Host "  get      " -NoNewline -ForegroundColor Green
    Write-Host "<key> - Get value of a specific key"
    Write-Host "  view     " -NoNewline -ForegroundColor Green
    Write-Host "- View formatted data (Node.js)"
    Write-Host ""
    Write-Host "Monitoring Commands:" -ForegroundColor Yellow
    Write-Host "  monitor  " -NoNewline -ForegroundColor Green
    Write-Host "- Monitor Redis commands in real-time"
    Write-Host "  logs     " -NoNewline -ForegroundColor Green
    Write-Host "- View Redis logs"
    Write-Host "  cli      " -NoNewline -ForegroundColor Green
    Write-Host "- Open Redis CLI"
    Write-Host "  info     " -NoNewline -ForegroundColor Green
    Write-Host "- Show Redis server info"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\redis\redis-local.ps1 start" -ForegroundColor White
    Write-Host "  .\redis\redis-local.ps1 data" -ForegroundColor White
    Write-Host "  .\redis\redis-local.ps1 keys" -ForegroundColor White
    Write-Host "  .\redis\redis-local.ps1 keys rate_limit:*" -ForegroundColor White
    Write-Host "  .\redis\redis-local.ps1 get test:string" -ForegroundColor White
    Write-Host "  .\redis\redis-local.ps1 view" -ForegroundColor White
    Write-Host "  .\redis\redis-local.ps1 monitor" -ForegroundColor White
    Write-Host ""
}

# Execute command
switch ($Command) {
    'start'   { Start-Redis }
    'stop'    { Stop-Redis }
    'restart' { Restart-Redis }
    'status'  { Get-RedisStatus }
    'monitor' { Start-RedisMonitor }
    'logs'    { Get-RedisLogs }
    'cli'     { Start-RedisCli }
    'info'    { Get-RedisInfo }
    'ping'    { Test-RedisConnection }
    'data'    { Show-RedisData }
    'keys'    { Get-RedisKeys -Pattern $Arg1 }
    'get'     { Get-RedisKeyValue -Key $Arg1 }
    'view'    { Show-RedisDataFormatted }
    'help'    { Show-Help }
    default   { Show-Help }
}
