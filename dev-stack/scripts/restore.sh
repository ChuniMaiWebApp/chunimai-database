#!/usr/bin/env bash
#
# Restore script for Supabase Local Setup
# Compatible with Windows bash (Git Bash, WSL)
#
# This script:
# - Restores PostgreSQL data volume from backup archives
# - Restores storage data volume from backup archives
# - Verifies backup integrity before restoring
# - Handles restore errors gracefully

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory and base path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Change to base directory
cd "$BASE_DIR"

# Backup directory
BACKUP_DIR="$BASE_DIR/backups"

# Function to print colored messages
print_error() {
    echo -e "${RED}❌ Error: $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  Warning: $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS] <backup_file>"
    echo ""
    echo "Restore Supabase Local data volumes from backup archives"
    echo ""
    echo "Options:"
    echo "  --force           Skip confirmation prompt"
    echo "  --help, -h        Display this help message"
    echo ""
    echo "Arguments:"
    echo "  <backup_file>     Path to backup archive (.tar.gz)"
    echo "                    Can be absolute path or relative to backups directory"
    echo ""
    echo "Examples:"
    echo "  $0 supabase_db_backup_20240101_120000.tar.gz"
    echo "  $0 /path/to/backup.tar.gz"
    echo "  $0 --force supabase_storage_backup_20240101_120000.tar.gz"
    echo ""
    echo "Available backups:"
    if [ -d "$BACKUP_DIR" ] && [ "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        ls -1 "$BACKUP_DIR" | grep -E '\.tar\.gz$' | sed 's/^/  - /'
    else
        echo "  (no backups found)"
    fi
    echo ""
}

# Function to check if Docker daemon is running
check_docker() {
    print_info "Checking Docker daemon..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running"
        echo "Please start Docker Desktop and try again."
        exit 1
    fi
    
    print_success "Docker daemon is running"
}

# Function to check if docker-compose is available
check_docker_compose() {
    print_info "Checking docker-compose..."
    
    # Try docker compose (v2) first
    if docker compose version &> /dev/null; then
        DOCKER_COMPOSE="docker compose"
        print_success "Using docker compose (v2)"
        return 0
    fi
    
    # Fall back to docker-compose (v1)
    if command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE="docker-compose"
        print_success "Using docker-compose (v1)"
        return 0
    fi
    
    print_error "docker-compose not found"
    exit 1
}

# Function to resolve backup file path
resolve_backup_path() {
    local input_path=$1
    
    # If absolute path and exists, use it
    if [[ "$input_path" = /* ]] && [ -f "$input_path" ]; then
        echo "$input_path"
        return 0
    fi
    
    # If relative path and exists in current directory
    if [ -f "$input_path" ]; then
        echo "$(cd "$(dirname "$input_path")" && pwd)/$(basename "$input_path")"
        return 0
    fi
    
    # Try in backup directory
    if [ -f "$BACKUP_DIR/$input_path" ]; then
        echo "$BACKUP_DIR/$input_path"
        return 0
    fi
    
    # Not found
    return 1
}

# Function to verify backup file integrity
verify_backup_integrity() {
    local backup_file=$1
    
    print_info "Verifying backup integrity..."
    
    # Check if file exists
    if [ ! -f "$backup_file" ]; then
        print_error "Backup file not found: $backup_file"
        return 1
    fi
    
    # Check if file is readable
    if [ ! -r "$backup_file" ]; then
        print_error "Backup file is not readable: $backup_file"
        return 1
    fi
    
    # Check if file is a valid gzip archive
    if ! gzip -t "$backup_file" 2>/dev/null; then
        print_error "Backup file is not a valid gzip archive"
        return 1
    fi
    
    # Check if tar archive is valid
    if ! tar -tzf "$backup_file" &>/dev/null; then
        print_error "Backup file is not a valid tar archive"
        return 1
    fi
    
    # Get file size
    local size=$(du -h "$backup_file" | cut -f1)
    print_success "Backup integrity verified ($size)"
    
    return 0
}

# Function to determine backup type from filename
get_backup_type() {
    local backup_file=$1
    local filename=$(basename "$backup_file")
    
    if [[ "$filename" =~ supabase_db_backup ]]; then
        echo "db"
    elif [[ "$filename" =~ supabase_storage_backup ]]; then
        echo "storage"
    else
        echo "unknown"
    fi
}

# Function to check if services are running
check_services_running() {
    print_info "Checking if Supabase services are running..."
    
    local running_containers=$($DOCKER_COMPOSE ps -q 2>/dev/null | wc -l)
    
    if [ "$running_containers" -gt 0 ]; then
        print_warning "Supabase services are currently running"
        echo "It is recommended to stop services before restoring."
        echo ""
        return 0
    else
        print_info "No running services detected"
        return 1
    fi
}

# Function to prompt for confirmation
confirm_restore() {
    local backup_file=$1
    local backup_type=$2
    local force=$3
    
    if [ "$force" = "true" ]; then
        return 0
    fi
    
    echo ""
    echo "=========================================="
    echo "⚠️  RESTORE CONFIRMATION"
    echo "=========================================="
    echo ""
    echo "Backup file: $(basename "$backup_file")"
    echo "Backup type: $backup_type"
    echo ""
    echo "⚠️  WARNING: This will REPLACE existing data!"
    echo ""
    echo "Current data will be permanently lost."
    echo "Make sure you have a backup of current data if needed."
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_info "Restore cancelled by user"
        exit 0
    fi
}

# Function to restore PostgreSQL data volume
restore_db_volume() {
    local backup_file=$1
    local volume_name="supabase_db_data"
    
    print_info "Restoring PostgreSQL data volume..."
    
    # Create volume if it doesn't exist
    if ! docker volume inspect "$volume_name" &> /dev/null; then
        print_info "Creating volume: $volume_name"
        docker volume create "$volume_name"
    fi
    
    # Stop postgres container if running
    local postgres_container=$($DOCKER_COMPOSE ps -q postgres 2>/dev/null)
    if [ -n "$postgres_container" ]; then
        print_info "Stopping PostgreSQL container..."
        $DOCKER_COMPOSE stop postgres
    fi
    
    # Remove existing data in volume
    print_info "Clearing existing data..."
    docker run --rm \
        -v "${volume_name}:/data" \
        alpine:latest \
        sh -c "rm -rf /data/* /data/..?* /data/.[!.]* 2>/dev/null || true"
    
    # Restore backup to volume
    print_info "Extracting backup archive..."
    docker run --rm \
        -v "${volume_name}:/data" \
        -v "$(dirname "$backup_file"):/backup" \
        alpine:latest \
        tar xzf "/backup/$(basename "$backup_file")" -C /data
    
    # Verify restore
    local file_count=$(docker run --rm \
        -v "${volume_name}:/data" \
        alpine:latest \
        sh -c "find /data -type f | wc -l")
    
    if [ "$file_count" -gt 0 ]; then
        print_success "PostgreSQL data restored successfully ($file_count files)"
        return 0
    else
        print_error "Restore verification failed: no files found in volume"
        return 1
    fi
}

# Function to restore storage data volume
restore_storage_volume() {
    local backup_file=$1
    local volume_name="supabase_storage_data"
    
    print_info "Restoring storage data volume..."
    
    # Create volume if it doesn't exist
    if ! docker volume inspect "$volume_name" &> /dev/null; then
        print_info "Creating volume: $volume_name"
        docker volume create "$volume_name"
    fi
    
    # Stop storage container if running
    local storage_container=$($DOCKER_COMPOSE ps -q storage 2>/dev/null)
    if [ -n "$storage_container" ]; then
        print_info "Stopping storage container..."
        $DOCKER_COMPOSE stop storage
    fi
    
    # Remove existing data in volume
    print_info "Clearing existing data..."
    docker run --rm \
        -v "${volume_name}:/data" \
        alpine:latest \
        sh -c "rm -rf /data/* /data/..?* /data/.[!.]* 2>/dev/null || true"
    
    # Restore backup to volume
    print_info "Extracting backup archive..."
    docker run --rm \
        -v "${volume_name}:/data" \
        -v "$(dirname "$backup_file"):/backup" \
        alpine:latest \
        tar xzf "/backup/$(basename "$backup_file")" -C /data
    
    # Verify restore
    local file_count=$(docker run --rm \
        -v "${volume_name}:/data" \
        alpine:latest \
        sh -c "find /data -type f | wc -l")
    
    if [ "$file_count" -gt 0 ]; then
        print_success "Storage data restored successfully ($file_count files)"
        return 0
    else
        print_warning "Restore completed but no files found (backup may have been empty)"
        return 0
    fi
}

# Function to display restore summary
display_summary() {
    local backup_type=$1
    local success=$2
    
    echo ""
    echo "=========================================="
    if [ "$success" = "true" ]; then
        echo "✅ Restore Complete"
    else
        echo "❌ Restore Failed"
    fi
    echo "=========================================="
    echo ""
    
    if [ "$success" = "true" ]; then
        echo "📊 Restore Status:"
        echo "  ✅ $backup_type data restored successfully"
        echo ""
        echo "📚 Next steps:"
        echo "  - Start services: ./scripts/start.sh"
        echo "  - Check status: ./scripts/status.sh"
        echo "  - View logs: ./scripts/logs.sh"
        echo ""
    else
        echo "❌ Restore failed. Please check the error messages above."
        echo ""
        echo "📚 Troubleshooting:"
        echo "  - Verify backup file integrity"
        echo "  - Check Docker daemon is running"
        echo "  - Ensure sufficient disk space"
        echo "  - Check logs: ./scripts/logs.sh"
        echo ""
    fi
    
    echo "=========================================="
}

# Main execution
main() {
    # Parse command line arguments
    local force="false"
    local backup_file=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                force="true"
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            -*)
                print_error "Unknown option: $1"
                echo ""
                usage
                exit 1
                ;;
            *)
                if [ -z "$backup_file" ]; then
                    backup_file=$1
                else
                    print_error "Multiple backup files specified"
                    echo ""
                    usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Check if backup file was provided
    if [ -z "$backup_file" ]; then
        print_error "No backup file specified"
        echo ""
        usage
        exit 1
    fi
    
    # Display header
    echo "🔄 Restoring Supabase Local data..."
    echo ""
    
    # Check prerequisites
    check_docker
    check_docker_compose
    
    # Resolve backup file path
    print_info "Resolving backup file path..."
    if ! resolved_path=$(resolve_backup_path "$backup_file"); then
        print_error "Backup file not found: $backup_file"
        echo ""
        echo "Available backups:"
        if [ -d "$BACKUP_DIR" ] && [ "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
            ls -1 "$BACKUP_DIR" | grep -E '\.tar\.gz$' | sed 's/^/  - /'
        else
            echo "  (no backups found)"
        fi
        exit 1
    fi
    backup_file="$resolved_path"
    print_success "Backup file found: $(basename "$backup_file")"
    
    # Verify backup integrity
    if ! verify_backup_integrity "$backup_file"; then
        print_error "Backup integrity check failed"
        exit 1
    fi
    
    # Determine backup type
    backup_type=$(get_backup_type "$backup_file")
    if [ "$backup_type" = "unknown" ]; then
        print_error "Cannot determine backup type from filename"
        echo "Expected filename pattern: supabase_db_backup_*.tar.gz or supabase_storage_backup_*.tar.gz"
        exit 1
    fi
    print_info "Detected backup type: $backup_type"
    
    # Check if services are running
    check_services_running
    
    # Confirm restore
    confirm_restore "$backup_file" "$backup_type" "$force"
    
    # Perform restore
    local success="false"
    
    case "$backup_type" in
        db)
            if restore_db_volume "$backup_file"; then
                success="true"
            fi
            ;;
        storage)
            if restore_storage_volume "$backup_file"; then
                success="true"
            fi
            ;;
        *)
            print_error "Unknown backup type: $backup_type"
            exit 1
            ;;
    esac
    
    # Display summary
    display_summary "$backup_type" "$success"
    
    # Exit with appropriate code
    if [ "$success" = "true" ]; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"
