#!/usr/bin/env bash
#
# Start script for Supabase Local Setup
# Compatible with Windows bash (Git Bash, WSL)
#
# This script:
# - Checks Docker daemon is running
# - Validates configuration files
# - Starts all Supabase services
# - Waits for health checks
# - Displays service URLs

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

echo "🚀 Starting Supabase Local Setup..."
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
        echo "Please install Docker Desktop and try again."
        echo "Download from: https://www.docker.com/products/docker-desktop"
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
    echo "Please install Docker Compose and try again."
    exit 1
}

# Function to check port availability
check_ports() {
    print_info "Checking port availability..."
    
    # Check if Python is available
    if ! command -v python3 &> /dev/null && ! command -v python &> /dev/null; then
        print_warning "Python not found, skipping port check"
        return 0
    fi
    
    # Determine Python command
    PYTHON_CMD="python3"
    if ! command -v python3 &> /dev/null; then
        PYTHON_CMD="python"
    fi
    
    # Run port check script
    if [ -f "$SCRIPT_DIR/check_ports.py" ]; then
        if $PYTHON_CMD "$SCRIPT_DIR/check_ports.py"; then
            print_success "All required ports are available"
        else
            print_error "Port conflicts detected"
            echo ""
            echo "Please resolve the port conflicts above before starting."
            echo "You can either:"
            echo "  1. Stop the conflicting processes"
            echo "  2. Change port mappings in docker-compose.yml and .env"
            echo "  3. Stop any previous Docker containers: docker-compose down"
            exit 1
        fi
    else
        print_warning "Port check script not found, skipping port check"
    fi
}

# Function to validate configuration files
validate_config() {
    print_info "Validating configuration files..."
    
    # Check if Python is available
    if ! command -v python3 &> /dev/null && ! command -v python &> /dev/null; then
        print_warning "Python not found, skipping validation"
        return 0
    fi
    
    # Determine Python command
    PYTHON_CMD="python3"
    if ! command -v python3 &> /dev/null; then
        PYTHON_CMD="python"
    fi
    
    # Run validation script
    if [ -f "$SCRIPT_DIR/validate_config.py" ]; then
        if $PYTHON_CMD "$SCRIPT_DIR/validate_config.py"; then
            print_success "Configuration validation passed"
        else
            print_error "Configuration validation failed"
            echo "Please fix the errors above and try again."
            exit 1
        fi
    else
        print_warning "Validation script not found, skipping validation"
    fi
}

# Function to start services
start_services() {
    print_info "Starting Supabase services..."
    echo ""
    
    # Pull images first (optional, but good for first run)
    print_info "Pulling Docker images (this may take a while on first run)..."
    $DOCKER_COMPOSE pull
    
    echo ""
    print_info "Starting containers..."
    $DOCKER_COMPOSE up -d
    
    print_success "All containers started"
}

# Function to wait for health checks
wait_for_health() {
    print_info "Waiting for services to be healthy..."
    echo ""
    
    local max_wait=60
    local elapsed=0
    local check_interval=2
    
    while [ $elapsed -lt $max_wait ]; do
        # Check PostgreSQL health
        if $DOCKER_COMPOSE ps postgres | grep -q "healthy"; then
            print_success "PostgreSQL is healthy"
            break
        fi
        
        echo -n "."
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
    done
    
    echo ""
    
    if [ $elapsed -ge $max_wait ]; then
        print_warning "Health check timeout reached"
        print_info "Services may still be starting up. Check status with: ./scripts/status.sh"
    else
        # Wait a bit more for other services
        print_info "Waiting for other services to initialize..."
        sleep 5
        print_success "Services are ready"
    fi
}

# Function to display service URLs
display_urls() {
    echo ""
    echo "=========================================="
    echo "🎉 Supabase Local is running!"
    echo "=========================================="
    echo ""
    echo "📍 Service URLs:"
    echo "  - Studio (Web UI):    http://localhost:3000"
    echo "  - API Gateway:        http://localhost:8095"
    echo "  - PostgreSQL:         localhost:5432"
    echo "  - Auth API:           http://localhost:9999"
    echo "  - PostgREST API:      http://localhost:3001"
    echo "  - Realtime:           http://localhost:4000"
    echo "  - Storage:            http://localhost:5000"
    echo ""
    echo "📚 Next steps:"
    echo "  - Open Studio in your browser: http://localhost:3000"
    echo "  - Check service status: ./scripts/status.sh"
    echo "  - View logs: ./scripts/logs.sh"
    echo "  - Stop services: ./scripts/stop.sh"
    echo ""
    echo "=========================================="
}

# Main execution
main() {
    check_docker
    check_docker_compose
    check_ports
    validate_config
    start_services
    wait_for_health
    display_urls
}

# Run main function
main
