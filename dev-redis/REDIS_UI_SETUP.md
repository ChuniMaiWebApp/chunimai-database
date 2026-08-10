# Redis UI Setup Guide for Windows

## Recommended: RedisInsight (Official Redis GUI)

RedisInsight is the official free GUI tool from Redis. It's the best option for Windows.

### Installation

1. **Download RedisInsight**
   - Visit: https://redis.io/insight/
   - Click "Download for Windows"
   - Or direct link: https://redis.io/downloads/

2. **Install**
   - Run the downloaded installer
   - Follow the installation wizard
   - Launch RedisInsight

3. **Connect to Local Redis**
   - Click "Add Redis Database"
   - Enter connection details:
     - **Host:** localhost
     - **Port:** 6379
     - **Name:** ArtHub Local Redis
     - **Username:** (leave empty)
     - **Password:** (leave empty)
   - Click "Add Redis Database"

### Features

- **Browser:** View and edit keys with a visual interface
- **Workbench:** Execute Redis commands with autocomplete
- **Analysis Tools:** Memory analysis, slow log, profiler
- **CLI:** Built-in Redis CLI
- **Pub/Sub:** Monitor Redis pub/sub channels
- **Streams:** Visualize Redis Streams

### Screenshots

After connecting, you'll see:
- Left sidebar: Database list
- Main area: Key browser with search
- Bottom: Command line interface
- Top right: Database info and tools

## Alternative: Another Redis Desktop Manager

If you prefer a lighter alternative:

### Installation

1. **Download**
   - Visit: https://github.com/qishibo/AnotherRedisDesktopManager/releases
   - Download the latest `.exe` for Windows
   - Or use: https://github.com/qishibo/AnotherRedisDesktopManager

2. **Install**
   - Run the installer
   - Launch the application

3. **Connect**
   - Click "New Connection"
   - Enter:
     - **Name:** ArtHub Local
     - **Host:** 127.0.0.1
     - **Port:** 6379
     - **Auth:** (leave empty)
   - Click "Test Connection"
   - Click "OK"

## Alternative: Redis Commander (Web-based)

For a web-based interface:

### Installation

```powershell
# Install globally
npm install -g redis-commander

# Start Redis Commander
redis-commander

# Open browser at http://localhost:8081
```

### Usage

- Access via browser: http://localhost:8081
- No installation required (runs in browser)
- Simple key-value browser
- Execute commands via web interface

## Monitoring Redis in Real-time

### Option 1: PowerShell Script
```powershell
.\redis-local.ps1 monitor
```

### Option 2: Direct WSL Command
```powershell
wsl redis-cli monitor
```

### Option 3: RedisInsight Profiler
1. Open RedisInsight
2. Click "Profiler" in the left sidebar
3. Click "Start Profiler"
4. See all commands in real-time with timing

## Common Redis Commands in UI

### In RedisInsight Workbench:

```redis
# View all keys
KEYS *

# View keys by pattern
KEYS rate_limit:*
KEYS blocked_ip:*
KEYS image_token:*

# Get a key value
GET rate_limit:ip:192.168.1.1

# Set a key
SET test:key "test value"

# Set with expiration
SETEX test:key 60 "expires in 60 seconds"

# Check TTL
TTL image_token:abc123

# Delete a key
DEL test:key

# Get server info
INFO

# Get memory stats
INFO memory

# Get stats
INFO stats

# Monitor commands (in CLI tab)
MONITOR

# Clear all data (BE CAREFUL!)
FLUSHALL
```

## Content Protection Keys to Monitor

### Rate Limiting Keys
```redis
# View all rate limit keys
KEYS rate_limit:*

# Check specific IP rate limit
GET rate_limit:ip:192.168.1.1

# Check user rate limit
GET rate_limit:user:user-id-123
```

### Blocked IPs
```redis
# View all blocked IPs
KEYS blocked_ip:*

# Check if IP is blocked
GET blocked_ip:192.168.1.1

# Check TTL of block
TTL blocked_ip:192.168.1.1
```

### Image Access Tokens
```redis
# View all active tokens
KEYS image_token:*

# Check token details
GET image_token:abc123token

# Check token TTL
TTL image_token:abc123token
```

### Processed Images Cache
```redis
# View cached images
KEYS image:processed:*

# Check cache TTL
TTL image:processed:image-id-123
```

### User Risk Scores
```redis
# View all risk scores
KEYS risk_score:*

# Check user risk score
GET risk_score:user-id-123
```

## Tips for Using Redis UI

### 1. Search and Filter
- Use the search box to filter keys by pattern
- Example: `rate_limit:*` to see all rate limiting keys

### 2. Bulk Operations
- Select multiple keys and delete them at once
- Be careful with bulk delete!

### 3. Export/Import
- Export keys to JSON for backup
- Import keys from JSON

### 4. Memory Analysis
- Use RedisInsight's memory analysis tool
- Find keys consuming most memory
- Identify memory leaks

### 5. Slow Log
- Monitor slow commands
- Optimize queries that take too long

### 6. Real-time Monitoring
- Use the profiler to see commands as they execute
- Identify bottlenecks
- Debug issues

## Troubleshooting

### Can't connect to Redis
1. Make sure Redis is running:
   ```powershell
   .\redis-local.ps1 status
   ```

2. Test connection:
   ```powershell
   wsl redis-cli ping
   ```

3. Check if port 6379 is open:
   ```powershell
   netstat -an | findstr 6379
   ```

### RedisInsight shows "Connection refused"
- Ensure Redis is running in WSL
- Try connecting to `127.0.0.1` instead of `localhost`
- Check Windows Firewall settings

### Keys not showing up
- Click the refresh button
- Check the database number (should be 0)
- Verify keys exist: `wsl redis-cli KEYS *`

## Best Practices

1. **Don't use FLUSHALL in production**
   - It deletes ALL data
   - Use with extreme caution

2. **Use key patterns for organization**
   - Prefix keys by feature: `rate_limit:`, `image:`, etc.
   - Makes it easier to find and manage keys

3. **Monitor memory usage**
   - Check `INFO memory` regularly
   - Set up alerts for high memory usage

4. **Use TTL for temporary data**
   - All cache keys should have expiration
   - Prevents memory leaks

5. **Regular backups**
   - Use `SAVE` or `BGSAVE` for backups
   - Store backup files safely

## Resources

- RedisInsight Documentation: https://redis.io/docs/ui/insight/
- Redis Commands Reference: https://redis.io/commands/
- Redis Best Practices: https://redis.io/docs/manual/patterns/
- Another Redis Desktop Manager: https://github.com/qishibo/AnotherRedisDesktopManager
