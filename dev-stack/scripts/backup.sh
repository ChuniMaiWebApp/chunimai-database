#!/usr/bin/env bash
#
# Backup script for Supabase Local Setup
# Compatible with Windows bash (Git Bash, WSL)
#
# This script:
# - Backs up PostgreSQL data volume
# - Backs up storage data volume
# - Creates timestamped backup archives
# - Stores backups in ./backups directory

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
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Backup Supabase Local data volumes"
    echo ""
    echo "Options:"
    echo "  --db-only         Backup only PostgreSQL data volume"
    echo "  --storage-only    Backup only storage data volume"
    echo "  --help, -h        Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0                # Backup both database and storage"
    echo "  $0 --db-only      # Backup only database"
    echo "  $0 --storage-only # Backup only storage"
    echo ""
    echo "Backups are stored in: $BACKUP_DIR"
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

# Function to create backup directory
create_backup_dir() {
    if [ ! -d "$BACKUP_DIR" ]; then
        print_info "Creating backup directory..."
        mkdir -p "$BACKUP_DIR"
        print_success "Backup directory created: $BACKUP_DIR"
    fi
}

# Function to generate timestamp
get_timestamp() {
    date +"%Y%m%d_%H%M%S"
}

# Function to check if volume exists
check_volume_exists() {
    local volume_name=$1
    
    if ! docker volume inspect "$volume_name" &> /dev/null; then
        print_error "Volume '$volume_name' does not exist"
        echo "Please ensure Supabase has been started at least once."
        return 1
    fi
    
    return 0
}

# Function to backup PostgreSQL data volume
backup_db_volume() {
    local timestamp=$(get_timestamp)
    local backup_file="$BACKUP_DIR/supabase_db_backup_${timestamp}.tar.gz"
    local volume_name="supabase_db_data"
    
    print_info "Backing up PostgreSQL data volume..."
    
    # Check if volume exists
    if ! check_volume_exists "$volume_name"; then
        return 1
    fi
    
    # Create backup using a temporary container
    print_info "Creating backup archive..."
    docker run --rm \
        -v "${volume_name}:/data" \
        -v "$BACKUP_DIR:/backup" \
        alpine:latest \
        tar czf "/backup/supabase_db_backup_${timestamp}.tar.gz" -C /data .
    
    # Check if backup was created successfully
    if [ -f "$backup_file" ]; then
        local size=$(du -h "$backup_file" | cut -f1)
        print_success "PostgreSQL backup created: $(basename "$backup_file") ($size)"
        return 0
    else
        print_error "Failed to create PostgreSQL backup"
        return 1
    fi
}

# Function to backup storage data volume
backup_storage_volume() {
    local timestamp=$(get_timestamp)
    local backup_file="$BACKUP_DIR/supabase_storage_backup_${timestamp}.tar.gz"
    local volume_name="supabase_storage_data"
    
    print_info "Backing up storage data volume..."
    
    # Check if volume exists
    if ! check_volume_exists "$volume_name"; then
        return 1
    fi
    
    # Create backup using a temporary container
    print_info "Creating backup archive..."
    docker run --rm \
        -v "${volume_name}:/data" \
        -v "$BACKUP_DIR:/backup" \
        alpine:latest \
        tar czf "/backup/supabase_storage_backup_${timestamp}.tar.gz" -C /data .
    
    # Check if backup was created successfully
    if [ -f "$backup_file" ]; then
        local size=$(du -h "$backup_file" | cut -f1)
        print_success "Storage backup created: $(basename "$backup_file") ($size)"
        return 0
    else
        print_error "Failed to create storage backup"
        return 1
    fi
}

# Function to display backup summary
display_summary() {
    local db_backed_up=$1
    local storage_backed_up=$2
    
    echo ""
    echo "=========================================="
    echo "💾 Backup Complete"
    echo "=========================================="
    echo ""
    echo "📊 Backup Status:"
    
    if [ "$db_backed_up" = "true" ]; then
        echo "  ✅ PostgreSQL:  Backed up"
    else
        echo "  ⏭️  PostgreSQL:  Skipped"
    fi
    
    if [ "$storage_backed_up" = "true" ]; then
        echo "  ✅ Storage:     Backed up"
    else
        echo "  ⏭️  Storage:     Skipped"
    fi
    
    echo ""
    echo "📁 Backup location: $BACKUP_DIR"
    echo ""
    
    # List recent backups
    if [ -d "$BACKUP_DIR" ] && [ "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        echo "📦 Recent backups:"
        ls -lh "$BACKUP_DIR" | tail -n +2 | awk '{print "  - " $9 " (" $5 ")"}'
        echo ""
    fi
    
    echo "📚 Next steps:"
    echo "  - Restore backup: ./scripts/restore.sh <backup_file>"
    echo "  - List backups: ls -lh $BACKUP_DIR"
    echo ""
    echo "=========================================="
}

# Main execution
main() {
    # Parse command line arguments
    local backup_db="true"
    local backup_storage="true"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --db-only)
                backup_storage="false"
                shift
                ;;
            --storage-only)
                backup_db="false"
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo ""
                usage
                exit 1
                ;;
        esac
    done
    
    # Display header
    echo "💾 Backing up Supabase Local data..."
    echo ""
    
    # Check prerequisites
    check_docker
    check_docker_compose
    
    # Create backup directory
    create_backup_dir
    
    # Perform backups
    local db_backed_up="false"
    local storage_backed_up="false"
    
    if [ "$backup_db" = "true" ]; then
        if backup_db_volume; then
            db_backed_up="true"
        fi
        echo ""
    fi
    
    if [ "$backup_storage" = "true" ]; then
        if backup_storage_volume; then
            storage_backed_up="true"
        fi
        echo ""
    fi
    
    # Display summary
    display_summary "$db_backed_up" "$storage_backed_up"
}

# Run main function
main "$@"
