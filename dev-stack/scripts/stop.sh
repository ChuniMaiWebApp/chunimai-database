#!/usr/bin/env bash
#
# Stop script for Supabase Local Setup
# Compatible with Windows bash (Git Bash, WSL)
#
# This script:
# - Stops all Supabase services
# - Keeps volumes and networks intact
# - Displays cleanup status

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

echo "🛑 Stopping Supabase Local Setup..."
echo ""

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

# Function to stop services
stop_services() {
    print_info "Stopping Supabase services..."
    echo ""
    
    # Stop and remove containers, but keep volumes and networks
    $DOCKER_COMPOSE down
    
    print_success "All containers stopped and removed"
}

# Function to display cleanup status
display_status() {
    echo ""
    echo "=========================================="
    echo "✅ Supabase Local has been stopped"
    echo "=========================================="
    echo ""
    echo "📊 Cleanup Status:"
    echo "  ✅ Containers:  Stopped and removed"
    echo "  ✅ Networks:    Preserved"
    echo "  ✅ Volumes:     Preserved (data intact)"
    echo ""
    echo "💾 Your data is safe!"
    echo "  - Database data is preserved in volumes"
    echo "  - Storage files are preserved"
    echo ""
    echo "📚 Next steps:"
    echo "  - Restart services: ./scripts/start.sh"
    echo "  - Remove all data: ./scripts/cleanup.sh --volumes"
    echo "  - Check status: ./scripts/status.sh"
    echo ""
    echo "=========================================="
}

# Main execution
main() {
    check_docker
    check_docker_compose
    stop_services
    display_status
}

# Run main function
main
