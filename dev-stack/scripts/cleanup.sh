#!/usr/bin/env bash
#
# Cleanup script for Supabase Local Setup
# Compatible with Windows bash (Git Bash, WSL)
#
# This script:
# - Executes docker-compose down to remove containers and networks
# - Supports --volumes flag to delete data volumes
# - Displays cleanup progress

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
    echo "Clean up Supabase Local resources"
    echo ""
    echo "Options:"
    echo "  --volumes, -v     Remove data volumes (WARNING: This will delete all data!)"
    echo "  --help, -h        Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0                # Remove containers and networks, keep volumes"
    echo "  $0 --volumes      # Remove everything including data volumes"
    echo ""
    echo "⚠️  WARNING: Using --volumes will permanently delete all database data and storage files!"
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

# Function to confirm volume deletion
confirm_volume_deletion() {
    echo ""
    print_warning "You are about to delete ALL data volumes!"
    echo ""
    echo "This will permanently delete:"
    echo "  - All PostgreSQL database data"
    echo "  - All uploaded storage files"
    echo "  - All configuration and state"
    echo ""
    echo "This action CANNOT be undone!"
    echo ""
    
    read -p "Are you sure you want to continue? (yes/no): " -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_info "Cleanup cancelled by user"
        exit 0
    fi
    
    print_warning "Proceeding with volume deletion..."
}

# Function to cleanup resources
cleanup_resources() {
    local remove_volumes=$1
    
    print_info "Cleaning up Supabase resources..."
    echo ""
    
    # Build docker-compose down command
    local cmd="$DOCKER_COMPOSE down"
    
    # Add volumes flag if requested
    if [ "$remove_volumes" = "true" ]; then
        cmd="$cmd --volumes"
    fi
    
    # Display what will be removed
    print_info "Removing:"
    echo "  - Containers"
    echo "  - Networks"
    if [ "$remove_volumes" = "true" ]; then
        echo "  - Volumes (including all data)"
    else
        echo "  - Volumes: Preserved"
    fi
    echo ""
    
    # Execute cleanup
    print_info "Executing cleanup..."
    eval "$cmd"
    
    print_success "Cleanup completed"
}

# Function to display cleanup status
display_status() {
    local removed_volumes=$1
    
    echo ""
    echo "=========================================="
    echo "🧹 Cleanup Complete"
    echo "=========================================="
    echo ""
    echo "📊 Cleanup Status:"
    echo "  ✅ Containers:  Removed"
    echo "  ✅ Networks:    Removed"
    
    if [ "$removed_volumes" = "true" ]; then
        echo "  ✅ Volumes:     Removed (all data deleted)"
        echo ""
        echo "⚠️  All data has been permanently deleted!"
        echo ""
        echo "📚 Next steps:"
        echo "  - Start fresh: ./scripts/start.sh"
    else
        echo "  ✅ Volumes:     Preserved (data intact)"
        echo ""
        echo "💾 Your data is safe!"
        echo "  - Database data is preserved in volumes"
        echo "  - Storage files are preserved"
        echo ""
        echo "📚 Next steps:"
        echo "  - Restart services: ./scripts/start.sh"
        echo "  - Remove all data: ./scripts/cleanup.sh --volumes"
    fi
    
    echo ""
    echo "=========================================="
}

# Main execution
main() {
    # Parse command line arguments
    local remove_volumes="false"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --volumes|-v)
                remove_volumes="true"
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
    echo "🧹 Cleaning up Supabase Local Setup..."
    echo ""
    
    # Check prerequisites
    check_docker
    check_docker_compose
    
    # Confirm if removing volumes
    if [ "$remove_volumes" = "true" ]; then
        confirm_volume_deletion
    fi
    
    # Perform cleanup
    cleanup_resources "$remove_volumes"
    
    # Display status
    display_status "$remove_volumes"
}

# Run main function
main "$@"
