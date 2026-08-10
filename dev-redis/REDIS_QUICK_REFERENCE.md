# Redis Quick Reference

## Start/Stop Commands

```powershell
# Start Redis
.\redis-local.ps1 start

# Stop Redis
.\redis-local.ps1 stop

# Restart Redis
.\redis-local.ps1 restart

# Check status
.\redis-local.ps1 status

# Test connection
.\redis-local.ps1 ping
```

## Monitoring Commands

```powershell
# Monitor all Redis commands in real-time
.\redis-local.ps1 monitor
# or
wsl redis-cli monitor

# View logs
.\redis-local.ps1 logs

# Open Redis CLI
.\redis-local.ps1 cli

# Get server info
.\redis-local.ps1 info
```

## Common Redis CLI Commands

```bash
# Connect to Redis
wsl redis-cli

# Test connection
PING

# View all keys
KEYS *

# View keys by pattern
KEYS rate_limit:*

# Get a key
GET mykey

# Set a key
SET mykey "value"

# Set with expiration (seconds)
SETEX mykey 60 "expires in 60s"

# Delete a key
DEL mykey

# Check if key exists
EXISTS mykey

# Get TTL
TTL mykey

# Increment counter
INCR counter

# Get server info
INFO

# Clear all data (CAREFUL!)
FLUSHALL
```

## Content Protection Keys

```bash
# Rate limiting
KEYS rate_limit:*
GET rate_limit:ip:192.168.1.1

# Blocked IPs
KEYS blocked_ip:*
GET blocked_ip:192.168.1.1

# Image tokens
KEYS image_token:*
TTL image_token:abc123

# Cached images
KEYS image:processed:*

# Risk scores
KEYS risk_score:*
GET risk_score:user-id-123
```

## Configuration

- Host: localhost
- Port: 6379
- Password: (none)
- Database: 0

## UI Tools

- RedisInsight: https://redis.io/insight/
- Another Redis Desktop Manager: https://github.com/qishibo/AnotherRedisDesktopManager
