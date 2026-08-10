# Error Handling in start.sh

This document describes the error handling features implemented in the `start.sh` script.

## Overview

The `start.sh` script now includes comprehensive error handling to ensure a smooth startup experience and provide helpful error messages when issues occur.

## Error Handling Features

### 1. Docker Daemon Status Check

**Function**: `check_docker()`

**Checks**:
- Docker is installed and in PATH
- Docker daemon is running

**Error Messages**:
```
❌ Error: Docker is not installed or not in PATH
Please install Docker Desktop and try again.
Download from: https://www.docker.com/products/docker-desktop

❌ Error: Docker daemon is not running
Please start Docker Desktop and try again.
```

**Exit Code**: 1 (on failure)

---

### 2. Docker Compose Availability Check

**Function**: `check_docker_compose()`

**Checks**:
- Docker Compose v2 (`docker compose`) is available
- Falls back to Docker Compose v1 (`docker-compose`) if v2 not found

**Error Messages**:
```
❌ Error: docker-compose not found
Please install Docker Compose and try again.
```

**Exit Code**: 1 (on failure)

---

### 3. Port Availability Check

**Function**: `check_ports()`

**Checks**:
- All required ports (3000, 3001, 4000, 5000, 5432, 8095, 9999) are available
- Uses `check_ports.py` script to detect port conflicts
- Lists processes using conflicting ports

**Error Messages**:
```
❌ Error: Port conflicts detected

Please resolve the port conflicts above before starting.
You can either:
  1. Stop the conflicting processes
  2. Change port mappings in docker-compose.yml and .env
  3. Stop any previous Docker containers: docker-compose down
```

**Exit Code**: 1 (on failure)

**Graceful Degradation**: If Python is not available, the check is skipped with a warning.

---

### 4. Configuration File Validation

**Function**: `validate_config()`

**Checks**:
- `docker-compose.yml` exists and has valid YAML syntax
- All required services are defined
- Port mappings are valid
- Volumes and networks are configured
- `.env` file exists and has all required variables
- `JWT_SECRET` is at least 32 characters long
- Port numbers are valid (1-65535)

**Error Messages**:
```
❌ Error: Configuration validation failed
Please fix the errors above and try again.
```

**Exit Code**: 1 (on failure)

**Graceful Degradation**: If Python is not available, the check is skipped with a warning.

---

## Execution Flow

The `main()` function executes error handling in the following order:

1. `check_docker()` - Verify Docker is available
2. `check_docker_compose()` - Verify Docker Compose is available
3. `check_ports()` - Verify ports are available
4. `validate_config()` - Verify configuration files are valid
5. `start_services()` - Start Docker containers
6. `wait_for_health()` - Wait for services to be healthy
7. `display_urls()` - Display service URLs

If any step fails, the script exits immediately with a non-zero exit code and displays a helpful error message.

---

## Color-Coded Output

The script uses color-coded output for better readability:

- 🔴 **Red** (`print_error`): Error messages
- 🟢 **Green** (`print_success`): Success messages
- 🟡 **Yellow** (`print_warning`): Warning messages
- 🔵 **Blue** (`print_info`): Informational messages

---

## Testing

A test script is provided to verify error handling implementation:

```bash
bash supabase-local/scripts/test_start_error_handling.sh
```

This test verifies:
- All error handling functions exist
- Functions are called in the correct order
- Required helper scripts exist
- Script has valid bash syntax

---

## Requirements Validation

This implementation satisfies **Requirement 3.1** from the requirements document:

> **Yêu Cầu 3: Khởi Động Supabase Stack**
> 
> **Tiêu Chí Chấp Nhận 3.1**: WHEN người dùng chạy lệnh khởi động, THE Docker_Compose SHALL pull tất cả Docker images cần thiết

The error handling ensures that:
- ✅ Docker daemon status is checked
- ✅ Port availability is verified
- ✅ Configuration files are validated
- ✅ Helpful error messages are displayed

---

## Future Enhancements

Potential improvements for error handling:

1. **Network connectivity check**: Verify internet connection before pulling images
2. **Disk space check**: Verify sufficient disk space for Docker volumes
3. **Memory check**: Verify sufficient RAM for all services
4. **Automatic recovery**: Attempt to fix common issues automatically
5. **Detailed logging**: Write error logs to a file for debugging

---

# Error Handling in restore.sh

This document also describes the error handling features implemented in the `restore.sh` script.

## Overview

The `restore.sh` script includes comprehensive error handling to ensure safe and reliable data restoration with clear error messages when issues occur.

## Error Handling Features

### 1. Backup File Validation

**Function**: `verify_backup_integrity()`

**Checks**:
- Backup file exists
- File is readable
- File is a valid gzip archive
- File is a valid tar archive

**Error Messages**:
```
❌ Error: Backup file not found: <filename>

❌ Error: Backup file is not readable: <filename>

❌ Error: Backup file is not a valid gzip archive

❌ Error: Backup file is not a valid tar archive
```

**Exit Code**: 1 (on failure)

---

### 2. Backup Type Detection

**Function**: `get_backup_type()`

**Checks**:
- Filename matches expected pattern
- Detects database backup (`supabase_db_backup_*.tar.gz`)
- Detects storage backup (`supabase_storage_backup_*.tar.gz`)

**Error Messages**:
```
❌ Error: Cannot determine backup type from filename
Expected filename pattern: supabase_db_backup_*.tar.gz or supabase_storage_backup_*.tar.gz
```

**Exit Code**: 1 (on failure)

---

### 3. Backup File Path Resolution

**Function**: `resolve_backup_path()`

**Checks**:
- Absolute path exists
- Relative path exists in current directory
- File exists in backups directory

**Error Messages**:
```
❌ Error: Backup file not found: <filename>

Available backups:
  - supabase_db_backup_20240101_120000.tar.gz
  - supabase_storage_backup_20240101_120000.tar.gz
```

**Exit Code**: 1 (on failure)

---

### 4. Service Status Check

**Function**: `check_services_running()`

**Checks**:
- Whether Supabase services are currently running
- Warns user if services are running

**Warning Messages**:
```
⚠️  Warning: Supabase services are currently running
It is recommended to stop services before restoring.
```

**Note**: This is a warning, not an error. The script continues but stops affected services before restoring.

---

### 5. User Confirmation

**Function**: `confirm_restore()`

**Checks**:
- User confirms restore operation
- Can be skipped with `--force` flag

**Confirmation Prompt**:
```
==========================================
⚠️  RESTORE CONFIRMATION
==========================================

Backup file: supabase_db_backup_20240101_120000.tar.gz
Backup type: db

⚠️  WARNING: This will REPLACE existing data!

Current data will be permanently lost.
Make sure you have a backup of current data if needed.

Are you sure you want to continue? (yes/no):
```

**Exit Code**: 0 (if user cancels)

---

### 6. Restore Verification

**Functions**: `restore_db_volume()`, `restore_storage_volume()`

**Checks**:
- Volume is created successfully
- Container is stopped before restore
- Existing data is cleared
- Backup is extracted successfully
- Restored data is verified (file count check)

**Error Messages**:
```
❌ Error: Restore verification failed: no files found in volume
```

**Success Messages**:
```
✅ PostgreSQL data restored successfully (1234 files)

✅ Storage data restored successfully (567 files)
```

**Exit Code**: 1 (on failure)

---

## Execution Flow

The `main()` function executes error handling in the following order:

1. Parse command line arguments
2. `check_docker()` - Verify Docker is available
3. `check_docker_compose()` - Verify Docker Compose is available
4. `resolve_backup_path()` - Find backup file
5. `verify_backup_integrity()` - Validate backup file
6. `get_backup_type()` - Determine backup type
7. `check_services_running()` - Check service status
8. `confirm_restore()` - Get user confirmation
9. `restore_db_volume()` or `restore_storage_volume()` - Perform restore
10. `display_summary()` - Show restore results

If any step fails, the script exits immediately with a non-zero exit code and displays a helpful error message.

---

## Graceful Error Handling

The restore script handles errors gracefully:

- **Missing backup file**: Lists available backups
- **Corrupted backup**: Detects and reports integrity issues
- **Wrong backup type**: Validates filename pattern
- **Docker not running**: Clear error message with instructions
- **Restore failure**: Shows error and troubleshooting steps

---

## Testing

Test scripts are provided to verify restore functionality:

```bash
# Basic functionality tests
bash supabase-local/scripts/test_restore.sh

# Integration tests with mock backups
bash supabase-local/scripts/test_restore_integration.sh
```

These tests verify:
- All error handling functions exist
- Backup integrity verification works
- Backup type detection works
- Error messages are displayed correctly
- Script has valid bash syntax

---

## Requirements Validation

This implementation satisfies **Requirement 6.3** from the requirements document:

> **Yêu Cầu 6: Quản Lý Database**
> 
> **Tiêu Chí Chấp Nhận 6.3**: WHEN Supabase_Stack được restart, THE PostgreSQL SHALL load data từ volume

The error handling ensures that:
- ✅ Backup integrity is verified before restore
- ✅ User is warned about data loss
- ✅ Services are stopped before restore
- ✅ Restore is verified after completion
- ✅ Helpful error messages are displayed

---
