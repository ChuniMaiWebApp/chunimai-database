# RedisInsight Quick Start Guide

## ✅ Data is Ready!

Redis now has **19 sample keys** ready to view:
- 5 Rate Limiting keys
- 2 Blocked IP keys  
- 3 Image Access Tokens
- 3 Processed Images
- 3 User Risk Scores
- 3 Test keys

## 🔄 How to See Data in RedisInsight

### Step 1: Refresh the Browser Tab
In RedisInsight, click the **refresh icon** (🔄) next to "2 min" at the top of the Browse tab.

Or press `Ctrl+R` to refresh the page.

### Step 2: Click the Folder Icon
Click the **folder/list icon** (📁) on the left side to see all keys.

### Step 3: Browse Keys
You should now see all 19 keys organized by pattern:
- `blocked_ip:*`
- `image:processed:*`
- `image_token:*`
- `rate_limit:*`
- `risk_score:*`
- `test:*`

### Step 4: View Key Details
Click on any key to see:
- **Value** (JSON formatted if applicable)
- **TTL** (Time To Live)
- **Type** (String, Hash, List, etc.)

## 🔍 Useful Filters

In the "Filter by Key Name or Pattern" search box, try:

```
rate_limit:*        # See all rate limiting keys
blocked_ip:*        # See blocked IPs
image_token:*       # See image access tokens
risk_score:*        # See user risk scores
test:*              # See test keys
```

## 💻 Alternative: View in Terminal

If RedisInsight still doesn't show data, you can view it in terminal:

```powershell
# View all keys
wsl redis-cli --scan

# View formatted data
cd nestjs-backend
node view-redis-data.js

# Monitor real-time commands
wsl redis-cli monitor

# Open Redis CLI
wsl redis-cli
```

## 🎯 Example Commands in RedisInsight Workbench

Click the **"Workbench"** tab and try these commands:

```redis
# View all keys
KEYS *

# Get a specific key
GET test:string

# Get rate limit for an IP
GET rate_limit:ip:192.168.1.100

# Get blocked IP info
GET blocked_ip:192.168.1.200

# Get image token
GET image_token:abc123def456

# Get user risk score
GET risk_score:user-789

# Check TTL of a key
TTL image_token:abc123def456

# View server info
INFO

# View memory usage
INFO memory
```

## 🔄 Regenerate Sample Data

If keys expired or you want fresh data:

```powershell
cd nestjs-backend
node populate-redis-sample.js
```

Then refresh RedisInsight.

## 📊 What Each Key Type Contains

### Rate Limiting Keys
```
rate_limit:ip:192.168.1.100 = "45"
rate_limit:user:user-123 = "25"
```
- Simple counters
- TTL: 60 seconds
- Used to track request counts

### Blocked IPs
```json
blocked_ip:192.168.1.200 = {
  "reason": "rate_limit_exceeded",
  "violationCount": 3,
  "blockedAt": "2026-03-31T12:22:35.312Z"
}
```
- JSON data
- TTL: 300 seconds (5 minutes)
- Tracks why IP was blocked

### Image Access Tokens
```json
image_token:abc123def456 = {
  "imageId": "img-001",
  "userId": "user-123",
  "used": false,
  "createdAt": "2026-03-31T12:22:35.314Z"
}
```
- JSON data
- TTL: 300 seconds (5 minutes)
- One-time use tokens

### User Risk Scores
```json
risk_score:user-789 = {
  "score": 85,
  "level": "high",
  "botDetections": 5,
  "rateLimitViolations": 8,
  "invalidTokenAttempts": 4,
  "suspiciousBehavior": 6,
  "lastCalculated": "2026-03-31T12:22:35.317Z"
}
```
- JSON data
- TTL: 3600 seconds (1 hour)
- Cached risk calculations

## 🎨 RedisInsight Features to Explore

### 1. Browser Tab
- View all keys
- Search and filter
- Edit values
- Delete keys
- Set TTL

### 2. Workbench Tab
- Execute Redis commands
- Autocomplete support
- Command history
- Results formatting

### 3. Analyze Tab
- Memory analysis
- Key patterns
- Memory usage by type
- Recommendations

### 4. Pub/Sub Tab
- Monitor pub/sub channels
- Subscribe to channels
- Publish messages

### 5. CLI Tab
- Built-in Redis CLI
- Same as `wsl redis-cli`
- Command history

## 🚨 Troubleshooting

### Still no data showing?

1. **Check Redis is running:**
   ```powershell
   .\redis-local.ps1 status
   ```

2. **Verify data exists:**
   ```powershell
   wsl redis-cli --scan
   ```

3. **Check database number:**
   - RedisInsight should show "db0" at the top
   - All our data is in database 0

4. **Try reconnecting:**
   - Click the database name at top
   - Click "Edit"
   - Click "Test Connection"
   - Click "Apply"

5. **Regenerate data:**
   ```powershell
   cd nestjs-backend
   node populate-redis-sample.js
   ```

### Keys disappeared?

Keys with TTL will expire automatically:
- Rate limiting keys: 60 seconds
- Blocked IPs: 300 seconds (5 minutes)
- Image tokens: 300 seconds (5 minutes)
- Risk scores: 3600 seconds (1 hour)
- Test keys: No expiration

Run `node populate-redis-sample.js` to create fresh data.

## 📝 Next Steps

1. ✅ Explore the data in RedisInsight
2. ✅ Try filtering by key patterns
3. ✅ Execute commands in Workbench
4. ✅ Monitor real-time with Profiler
5. ✅ Ready to continue with Task 3 (Rate Limiting Module)

## 💡 Pro Tips

- Use `Ctrl+Space` in Workbench for autocomplete
- Click "Profiler" to see commands in real-time
- Use "Analyze" to find memory-hungry keys
- Export keys to JSON for backup
- Set up alerts for memory usage
