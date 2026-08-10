# Supabase Local Scripts

This directory contains utility scripts for managing and validating the Supabase local setup.

## start.sh

Starts the Supabase local stack with all services.

### What it does:

1. **Checks Docker daemon** - Verifies Docker is installed and running
2. **Validates configuration** - Runs validate_config.py to check all config files
3. **Starts services** - Executes `docker-compose up -d` to start all containers
4. **Waits for health checks** - Monitors PostgreSQL health status
5. **Displays service URLs** - Shows all accessible service endpoints

### Usage:

```bash
# From the supabase-local directory
./scripts/start.sh

# Or with bash explicitly (Windows)
bash scripts/start.sh
```

### Requirements:

- Docker Desktop installed and running
- docker-compose (v1) or docker compose (v2)
- Python 3 (optional, for validation)
- Bash shell (Git Bash on Windows, or WSL)

### Service URLs (after successful start):

- Studio (Web UI): http://localhost:3000
- API Gateway: http://localhost:8095
- PostgreSQL: localhost:5432
- Auth API: http://localhost:9999
- PostgREST API: http://localhost:3001
- Realtime: http://localhost:4000
- Storage: http://localhost:5000

## stop.sh

Stops the Supabase local stack and removes containers while preserving data.

### What it does:

1. **Checks Docker daemon** - Verifies Docker is running
2. **Stops services** - Executes `docker-compose down` to stop all containers
3. **Preserves data** - Keeps volumes and networks intact
4. **Displays cleanup status** - Shows what was removed and what was preserved

### Usage:

```bash
# From the supabase-local directory
./scripts/stop.sh

# Or with bash explicitly (Windows)
bash scripts/stop.sh
```

## status.sh

Displays the current status of all Supabase services.

### What it does:

1. **Shows container status** - Displays running/stopped state of all services
2. **Checks PostgreSQL health** - Verifies database connection
3. **Checks API endpoints** - Tests accessibility of all API services
4. **Displays service URLs** - Shows all accessible endpoints

### Usage:

```bash
# From the supabase-local directory
./scripts/status.sh

# Or with bash explicitly (Windows)
bash scripts/status.sh
```

## cleanup.sh

Cleans up Supabase local resources with optional data volume removal.

### What it does:

1. **Checks Docker daemon** - Verifies Docker is running
2. **Removes containers** - Executes `docker-compose down` to remove all containers
3. **Removes networks** - Cleans up Docker networks
4. **Optional volume removal** - Can delete data volumes with `--volumes` flag
5. **Displays cleanup status** - Shows what was removed and what was preserved

### Usage:

```bash
# Remove containers and networks, keep data volumes
./scripts/cleanup.sh

# Remove everything including data volumes (WARNING: deletes all data!)
./scripts/cleanup.sh --volumes

# Display help
./scripts/cleanup.sh --help

# Or with bash explicitly (Windows)
bash scripts/cleanup.sh
bash scripts/cleanup.sh --volumes
```

### Options:

- `--volumes, -v` - Remove data volumes (WARNING: This will delete all data!)
- `--help, -h` - Display help message

### ⚠️ Warning:

Using the `--volumes` flag will **permanently delete**:
- All PostgreSQL database data
- All uploaded storage files
- All configuration and state

This action **CANNOT be undone**! The script will ask for confirmation before proceeding.

## logs.sh

Displays logs from Supabase services with filtering and follow options.

### What it does:

1. **Displays service logs** - Shows logs from docker-compose services
2. **Supports filtering** - Can show logs for specific services
3. **Real-time following** - Can follow logs in real-time with `-f` flag
4. **Timestamp display** - Shows timestamps for each log entry (enabled by default)
5. **Tail support** - Can limit output to last N lines

### Usage:

```bash
# Show all logs
./scripts/logs.sh

# Follow all logs in real-time
./scripts/logs.sh -f

# Show logs for specific service
./scripts/logs.sh postgres

# Follow logs for specific service
./scripts/logs.sh -f postgres

# Show last 100 lines of PostgreSQL logs
./scripts/logs.sh -n 100 postgres

# Show last 50 lines and follow
./scripts/logs.sh -f -n 50 postgres

# Display help
./scripts/logs.sh --help
```

### Options:

- `-f, --follow` - Follow log output (real-time)
- `-n, --tail NUM` - Number of lines to show from the end (default: all)
- `-t, --timestamps` - Show timestamps (enabled by default)
- `-h, --help` - Display help message

### Available Services:

- `postgres` - PostgreSQL database
- `rest` - PostgREST API
- `auth` - GoTrue authentication
- `realtime` - Realtime server
- `storage` - Storage API
- `kong` - Kong API Gateway
- `studio` - Supabase Studio UI

## backup.sh

Creates timestamped backup archives of PostgreSQL and storage data volumes.


Checks if all required ports are available before starting the Supabase stack.

### What it does:

1. **Checks port availability** - Verifies all 7 required ports are not in use
2. **Lists conflicting processes** - Shows process name, PID, and address for each port conflict
3. **Suggests solutions** - Provides commands to stop conflicting processes
4. **Cross-platform support** - Works on Windows, Linux, and macOS

### Usage:

```bash
# From the supabase-local directory
python scripts/check_ports.py
```

### Required Ports:

- `3000` - Studio (Web UI)
- `3001` - PostgREST (REST API)
- `4000` - Realtime
- `5000` - Storage API
- `5432` - PostgreSQL
- `8095` - Kong Gateway
- `9999` - GoTrue (Auth API)

### Exit codes:

- `0`: All ports are available
- `1`: One or more ports are in use

### Example Output:

```
Checking port availability for Supabase local setup...

✓ Available ports:
  - Port 3000 (Studio (Web UI))
  - Port 3001 (PostgREST (REST API))
  - Port 4000 (Realtime)
  - Port 5000 (Storage API)
  - Port 8095 (Kong Gateway)
  - Port 9999 (GoTrue (Auth API))

✗ Port conflicts detected:

  Port 5432 (PostgreSQL):
    Process: postgres.exe
    PID: 1234
    Address: 0.0.0.0:5432
    To stop: taskkill /PID 1234 /F

Suggested solutions:
  1. Stop the conflicting processes using the commands above
  2. Change the port mappings in docker-compose.yml
  3. Stop Docker containers if they're from a previous run:
     docker-compose down
```

### Requirements:

- Python 3.6 or higher
- Windows: `netstat` and `tasklist` (built-in)
- Linux/macOS: `lsof` or `ss` (usually pre-installed)

## health_check.py

Performs comprehensive health checks on all Supabase services with retry logic and detailed error reporting.

### What it does:

1. **Checks container status** - Verifies each container is running
2. **Performs service-specific health checks**:
   - PostgreSQL: Uses `pg_isready` command
   - HTTP services: Tests HTTP endpoints (PostgREST, Auth, Storage, Kong, Studio)
   - TCP services: Tests TCP connectivity (Realtime)
3. **Retry logic with exponential backoff** - Automatically retries failed checks with increasing delays
4. **Detailed error reporting** - Shows recent logs and troubleshooting suggestions for failed services
5. **Cross-platform support** - Works on Windows, Linux, and macOS

### Usage:

```bash
# From the supabase-local directory
python scripts/health_check.py
```

### Health Check Configuration:

Each service has its own health check configuration:

| Service | Check Type | Endpoint/Port | Max Retries | Initial Backoff |
|---------|-----------|---------------|-------------|-----------------|
| PostgreSQL | postgres | 5432 | 5 | 2.0s |
| PostgREST | http | http://localhost:3001/ | 5 | 1.0s |
| GoTrue Auth | http | http://localhost:9999/health | 5 | 1.0s |
| Realtime | tcp | 4000 | 5 | 1.0s |
| Storage | http | http://localhost:5000/status | 5 | 1.0s |
| Kong Gateway | http | http://localhost:8095/ | 5 | 1.0s |
| Studio | http | http://localhost:3000/ | 5 | 1.0s |

### Exit codes:

- `0`: All services are healthy
- `1`: One or more services are unhealthy

### Example Output (All Healthy):

```
Checking health of Supabase services...

Checking PostgreSQL... OK
Checking PostgREST... OK
Checking GoTrue Auth... OK
Checking Realtime... OK
Checking Storage... OK
Checking Kong Gateway... OK
Checking Studio... OK

[OK] Healthy services:
  - PostgreSQL
  - PostgREST
  - GoTrue Auth
  - Realtime
  - Storage
  - Kong Gateway
  - Studio

[OK] All services are healthy!
```

### Example Output (With Failures):

```
Checking health of Supabase services...

Checking PostgreSQL... FAIL
Checking PostgREST... FAIL
...

[FAIL] Unhealthy services:

  PostgreSQL:
    Error: Container not found: supabase-postgres
    Container: supabase-postgres

    Recent logs:
      Failed to get logs: Error response from daemon: No such container: supabase-postgres

Troubleshooting suggestions:
  1. Check container logs: docker logs <container-name>
  2. Restart the stack: docker-compose restart
  3. Check for port conflicts: python scripts/check_ports.py
  4. Verify configuration: python scripts/validate_config.py
  5. Check Docker resources (memory, CPU)
```

### Requirements:

- Python 3.6 or higher
- Docker installed and running
- `curl` command (optional, falls back to Python's urllib if not available)

### Retry Logic:

The script uses exponential backoff for retries:
- Attempt 1: Immediate
- Attempt 2: Wait 1.0s (or 2.0s for PostgreSQL)
- Attempt 3: Wait 2.0s (or 4.0s for PostgreSQL)
- Attempt 4: Wait 4.0s (or 8.0s for PostgreSQL)
- Attempt 5: Wait 8.0s (or 16.0s for PostgreSQL)
## backup.sh

Creates timestamped backup archives of PostgreSQL and storage data volumes.

### What it does:

1. **Checks Docker daemon** - Verifies Docker is installed and running
2. **Creates backup directory** - Ensures ./backups directory exists
3. **Backs up PostgreSQL volume** - Creates compressed archive of database data
4. **Backs up storage volume** - Creates compressed archive of uploaded files
5. **Displays backup summary** - Shows backup status and file sizes

### Usage:

```bash
# Backup both database and storage
./scripts/backup.sh

# Backup only database
./scripts/backup.sh --db-only

# Backup only storage
./scripts/backup.sh --storage-only

# Display help
./scripts/backup.sh --help

# Or with bash explicitly (Windows)
bash scripts/backup.sh
```

### Options:

- `--db-only` - Backup only PostgreSQL data volume
- `--storage-only` - Backup only storage data volume
- `--help, -h` - Display help message

### Backup Files:

Backups are stored in `./backups/` with timestamped filenames:
- `supabase_db_backup_YYYYMMDD_HHMMSS.tar.gz` - PostgreSQL data
- `supabase_storage_backup_YYYYMMDD_HHMMSS.tar.gz` - Storage data

### Example Output:

```
💾 Backing up Supabase Local data...

ℹ️  Checking Docker daemon...
✅ Docker daemon is running
ℹ️  Checking docker-compose...
✅ Using docker compose (v2)
ℹ️  Backing up PostgreSQL data volume...
ℹ️  Creating backup archive...
✅ PostgreSQL backup created: supabase_db_backup_20240101_120000.tar.gz (45M)

ℹ️  Backing up storage data volume...
ℹ️  Creating backup archive...
✅ Storage backup created: supabase_storage_backup_20240101_120000.tar.gz (12M)

==========================================
💾 Backup Complete
==========================================

📊 Backup Status:
  ✅ PostgreSQL:  Backed up
  ✅ Storage:     Backed up

📁 Backup location: /path/to/supabase-local/backups

📦 Recent backups:
  - supabase_db_backup_20240101_120000.tar.gz (45M)
  - supabase_storage_backup_20240101_120000.tar.gz (12M)

📚 Next steps:
  - Restore backup: ./scripts/restore.sh <backup_file>
  - List backups: ls -lh /path/to/supabase-local/backups

==========================================
```

### Requirements:

- Docker Desktop installed and running
- docker-compose (v1) or docker compose (v2)
- Bash shell (Git Bash on Windows, or WSL)
- Supabase volumes must exist (run start.sh at least once)

### Notes:

- Backups are created using temporary Alpine Linux containers
- Volumes do not need to be stopped for backup (but recommended for consistency)
- Backup files are compressed with gzip for space efficiency
- Old backups are not automatically deleted - manage them manually

## restore.sh

Restores PostgreSQL and storage data volumes from backup archives.

### What it does:

1. **Checks Docker daemon** - Verifies Docker is installed and running
2. **Verifies backup integrity** - Validates backup file is a valid gzip/tar archive
3. **Determines backup type** - Automatically detects database or storage backup
4. **Stops affected services** - Stops containers before restoring
5. **Restores data** - Extracts backup archive to volume
6. **Verifies restore** - Confirms data was restored successfully

### Usage:

```bash
# Restore from backup (with confirmation prompt)
./scripts/restore.sh supabase_db_backup_20240101_120000.tar.gz

# Restore with absolute path
./scripts/restore.sh /path/to/backup.tar.gz

# Restore without confirmation prompt
./scripts/restore.sh --force supabase_storage_backup_20240101_120000.tar.gz

# Display help and list available backups
./scripts/restore.sh --help

# Or with bash explicitly (Windows)
bash scripts/restore.sh supabase_db_backup_20240101_120000.tar.gz
```

### Options:

- `--force` - Skip confirmation prompt
- `--help, -h` - Display help message and list available backups

### Arguments:

- `<backup_file>` - Path to backup archive (.tar.gz)
  - Can be absolute path: `/path/to/backup.tar.gz`
  - Can be relative to backups directory: `supabase_db_backup_20240101_120000.tar.gz`
  - Can be relative to current directory: `./backup.tar.gz`

### Backup Types:

The script automatically detects backup type from filename:
- `supabase_db_backup_*.tar.gz` - PostgreSQL database backup
- `supabase_storage_backup_*.tar.gz` - Storage files backup

### Example Output:

```
🔄 Restoring Supabase Local data...

ℹ️  Checking Docker daemon...
✅ Docker daemon is running
ℹ️  Checking docker-compose...
✅ Using docker compose (v2)
ℹ️  Resolving backup file path...
✅ Backup file found: supabase_db_backup_20240101_120000.tar.gz
ℹ️  Verifying backup integrity...
✅ Backup integrity verified (45M)
ℹ️  Detected backup type: db
⚠️  Warning: Supabase services are currently running
It is recommended to stop services before restoring.

==========================================
⚠️  RESTORE CONFIRMATION
==========================================

Backup file: supabase_db_backup_20240101_120000.tar.gz
Backup type: db

⚠️  WARNING: This will REPLACE existing data!

Current data will be permanently lost.
Make sure you have a backup of current data if needed.

Are you sure you want to continue? (yes/no): yes

ℹ️  Restoring PostgreSQL data volume...
ℹ️  Stopping PostgreSQL container...
ℹ️  Clearing existing data...
ℹ️  Extracting backup archive...
✅ PostgreSQL data restored successfully (1234 files)

==========================================
✅ Restore Complete
==========================================

📊 Restore Status:
  ✅ db data restored successfully

📚 Next steps:
  - Start services: ./scripts/start.sh
  - Check status: ./scripts/status.sh
  - View logs: ./scripts/logs.sh

==========================================
```

### Requirements:

- Docker Desktop installed and running
- docker-compose (v1) or docker compose (v2)
- Bash shell (Git Bash on Windows, or WSL)
- Valid backup archive created by backup.sh

### ⚠️ Warning:

Restoring a backup will **permanently replace** existing data in the volume:
- All current PostgreSQL database data will be lost (for db backups)
- All current uploaded storage files will be lost (for storage backups)

This action **CANNOT be undone**! The script will ask for confirmation before proceeding (unless `--force` is used).

### Error Handling:

The script handles errors gracefully:
- **Backup file not found**: Lists available backups
- **Invalid backup file**: Verifies gzip and tar integrity
- **Unknown backup type**: Checks filename pattern
- **Restore failure**: Shows error messages and troubleshooting steps

### Notes:

- Services are automatically stopped before restoring
- Volumes are created if they don't exist
- Existing data is completely removed before restore
- Restore is verified by counting files in volume
- After restore, start services with `./scripts/start.sh`

## validate_config.py

Validates the Supabase local configuration files to ensure they are properly configured.

### What it does:

1. **Checks Docker daemon** - Verifies Docker is installed and running
2. **Checks docker-compose** - Verifies docker-compose is available
3. **Creates backup directory** - Ensures ./backups directory exists
4. **Backs up PostgreSQL data** - Creates compressed archive of database volume
5. **Backs up storage data** - Creates compressed archive of storage volume
6. **Displays backup summary** - Shows backup status and location

### Usage:

```bash
# Backup both database and storage
./scripts/backup.sh

# Backup only database
./scripts/backup.sh --db-only

# Backup only storage
./scripts/backup.sh --storage-only

# Display help
./scripts/backup.sh --help

# Or with bash explicitly (Windows)
bash scripts/backup.sh
```

### Options:

- `--db-only` - Backup only PostgreSQL data volume
- `--storage-only` - Backup only storage data volume
- `--help, -h` - Display help message

### Backup Files:

Backups are stored in `./backups/` directory with timestamped filenames:
- `supabase_db_backup_YYYYMMDD_HHMMSS.tar.gz` - PostgreSQL data
- `supabase_storage_backup_YYYYMMDD_HHMMSS.tar.gz` - Storage data

### Example Output:

```
💾 Backing up Supabase Local data...

ℹ️  Checking Docker daemon...
✅ Docker daemon is running
ℹ️  Checking docker-compose...
✅ Using docker compose (v2)
ℹ️  Backing up PostgreSQL data volume...
ℹ️  Creating backup archive...
✅ PostgreSQL backup created: supabase_db_backup_20240115_143022.tar.gz (125M)

ℹ️  Backing up storage data volume...
ℹ️  Creating backup archive...
✅ Storage backup created: supabase_storage_backup_20240115_143025.tar.gz (45M)

==========================================
💾 Backup Complete
==========================================

📊 Backup Status:
  ✅ PostgreSQL:  Backed up
  ✅ Storage:     Backed up

📁 Backup location: /path/to/supabase-local/backups

📦 Recent backups:
  - supabase_db_backup_20240115_143022.tar.gz (125M)
  - supabase_storage_backup_20240115_143025.tar.gz (45M)

📚 Next steps:
  - Restore backup: ./scripts/restore.sh <backup_file>
  - List backups: ls -lh /path/to/supabase-local/backups

==========================================
```

### Requirements:

- Docker Desktop installed and running
- docker-compose (v1) or docker compose (v2)
- Bash shell (Git Bash on Windows, or WSL)
- Supabase stack must have been started at least once (volumes must exist)

### Notes:

- Backups are created using temporary Alpine Linux containers
- The backup process does not stop running services
- Backup files are compressed with gzip for space efficiency
- Each backup has a unique timestamp to prevent overwrites

## validate_config.py

Validates the Supabase local configuration files to ensure they are properly configured.
## validate_config.py

Validates the Supabase local configuration files to ensure they are properly configured.

### What it validates:

**docker-compose.yml:**
- File exists and has valid YAML syntax
- All required services are defined (postgres, rest, auth, realtime, storage, kong, studio)
- Port mappings are valid (1-65535)
- Required volumes are defined (supabase_db_data)
- Required networks are defined (supabase_network)

**.env file:**
- File exists and is readable
- All required environment variables are present and non-empty:
  - POSTGRES_PASSWORD
  - POSTGRES_DB
  - POSTGRES_USER
  - JWT_SECRET
  - ANON_KEY
  - SERVICE_ROLE_KEY
  - API_EXTERNAL_URL
  - STUDIO_PORT
- JWT_SECRET is at least 32 characters long
- STUDIO_PORT is a valid port number (1-65535)

### Usage:

```bash
# From the supabase-local directory
python scripts/validate_config.py
```

### Exit codes:

- `0`: All validations passed
- `1`: One or more validations failed

### Requirements:

Install Python dependencies before running:

```bash
pip install -r requirements.txt
```
