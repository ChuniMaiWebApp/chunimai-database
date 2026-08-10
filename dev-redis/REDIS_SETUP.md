# Redis Setup Guide

## Overview

Redis is now installed and configured in WSL for the ArtHub content protection system.

## Quick Start

### Start Redis
```powershell
.\redis-local.ps1 start
```

### Stop Redis
```powershell
.\redis-local.ps1 stop
```

### Monitor Redis Commands (Real-time)
```powershell
.\redis-local.ps1 monitor
```
Or directly:
```powershell
wsl redis-cli monitor
```

### Check Status
```powershell
.\redis-local.ps1 status
```

### View Logs
```powershell
.\redis-local.ps1 logs
```

### Open Redis CLI
```powershell
.\redis-local.ps1 cli
```

### Test Connection
```powershell
.\redis-local.ps1 ping
```

## Available Commands

| Command | Description |
|---------|-------------|
| `start` | Start Redis server |
| `stop` | Stop Redis server |
| `restart` | Restart Redis server |
| `status` | Check Redis server status |
| `monitor` | Monitor Redis commands in real-time |
| `logs` | View Redis logs |
| `cli` | Open Redis CLI |
| `info` | Show Redis server info |
| `ping` | Test Redis connection |

## Configuration

Redis is configured to:
- **Host:** localhost (127.0.0.1)
- **Port:** 6379
- **Password:** None (local development)
- **Database:** 0 (default)

## Backend Configuration

The NestJS backend is configured to connect to Redis via environment variables:

```env
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_DB=0
```

## Redis CLI Commands

### Basic Commands
```bash
# Connect to Redis
wsl redis-cli

# Test connection
PING

# Set a key
SET mykey "Hello"

# Get a key
GET mykey

# List all keys
KEYS *

# Delete a key
DEL mykey

# Check if key exists
EXISTS mykey

# Set key with expiration (seconds)
SETEX mykey 60 "Expires in 60 seconds"

# Get time to live
TTL mykey

# Increment counter
INCR counter

# Get all info
INFO

# Monitor all commands
MONITOR

# Clear all data (BE CAREFUL!)
FLUSHALL
```

### Content Protection Keys

The content protection system uses these Redis key patterns:

```bash
# Rate limiting
rate_limit:ip:192.168.1.1
rate_limit:user:user-id-123

# Blocked IPs
blocked_ip:192.168.1.1

# Image access tokens
image_token:abc123token

# Processed images cache
image:processed:image-id-123

# User risk scores
risk_score:user-id-123
```

### Monitoring Examples

```bash
# Monitor all commands
wsl redis-cli monitor

# Get all rate limit keys
wsl redis-cli KEYS "rate_limit:*"

# Get all blocked IPs
wsl redis-cli KEYS "blocked_ip:*"

# Check a specific rate limit
wsl redis-cli GET "rate_limit:ip:192.168.1.1"

# Check TTL of a token
wsl redis-cli TTL "image_token:abc123"

# Get server stats
wsl redis-cli INFO stats

# Get memory usage
wsl redis-cli INFO memory
```

## Redis UI Tools (Optional)

### 1. RedisInsight (Recommended)
- Download: https://redis.io/insight/
- Free official GUI from Redis
- Features: Key browser, CLI, profiler, memory analysis

### 2. Another Redis Desktop Manager
- Download: https://github.com/qishibo/AnotherRedisDesktopManager
- Free and open source
- Cross-platform

### 3. Redis Commander (Web-based)
```bash
# Install globally
npm install -g redis-commander

# Run
redis-commander

# Open browser at http://localhost:8081
```

## Troubleshooting

### Redis not starting
```powershell
# Check if Redis is already running
wsl ps aux | grep redis

# Kill existing Redis processes
wsl sudo pkill redis-server

# Start Redis
.\redis-local.ps1 start
```

### Connection refused error
```powershell
# Check if Redis is running
.\redis-local.ps1 status

# Check Redis configuration
wsl cat /etc/redis/redis.conf | grep bind

# Should show: bind 127.0.0.1
```

### Backend can't connect
1. Make sure Redis is running: `.\redis-local.ps1 status`
2. Check `.env` file has correct Redis configuration
3. Restart backend: `npm run start:dev`

## Auto-start Redis on WSL Boot (Optional)

To automatically start Redis when WSL starts:

```bash
# Edit sudoers to allow redis-server without password
wsl sudo visudo

# Add this line:
# %sudo ALL=(ALL) NOPASSWD: /usr/sbin/service redis-server *

# Add to ~/.bashrc or ~/.zshrc
echo 'sudo service redis-server start > /dev/null 2>&1' >> ~/.bashrc
```

## Performance Monitoring

```bash
# Real-time stats
wsl redis-cli --stat

# Latency monitoring
wsl redis-cli --latency

# Big keys analysis
wsl redis-cli --bigkeys

# Memory usage by key pattern
wsl redis-cli --memkeys
```

## Backup and Restore

```bash
# Create backup
wsl redis-cli SAVE

# Backup file location
wsl ls -lh /var/lib/redis/dump.rdb

# Restore from backup
# 1. Stop Redis
.\redis-local.ps1 stop

# 2. Copy backup file to /var/lib/redis/dump.rdb
wsl sudo cp /path/to/backup/dump.rdb /var/lib/redis/dump.rdb

# 3. Start Redis
.\redis-local.ps1 start
```

## Security Notes

- Redis is configured for **local development only**
- No password is set (not recommended for production)
- Redis only binds to localhost (127.0.0.1)
- For production, use Redis Cloud or configure authentication

## Production Recommendations

For production deployment:

1. **Use Redis Cloud** (recommended)
   - Redis Enterprise Cloud
   - AWS ElastiCache
   - Azure Cache for Redis

2. **Or configure authentication**
   ```bash
   # Set password in redis.conf
   requirepass your-strong-password
   
   # Update .env
   REDIS_PASSWORD=your-strong-password
   ```

3. **Enable persistence**
   ```bash
   # In redis.conf
   save 900 1
   save 300 10
   save 60 10000
   ```

4. **Set maxmemory policy**
   ```bash
   # In redis.conf
   maxmemory 256mb
   maxmemory-policy allkeys-lru
   ```

## Resources

- Redis Documentation: https://redis.io/docs/
- Redis Commands: https://redis.io/commands/
- Redis Best Practices: https://redis.io/docs/manual/patterns/
- ioredis (Node.js client): https://github.com/redis/ioredis
