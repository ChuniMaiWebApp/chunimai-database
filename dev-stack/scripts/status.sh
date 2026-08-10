#!/usr/bin/env bash
#
# Status script for Supabase Local Setup
# Compatible with Windows bash (Git Bash, WSL)
#
# This script:
# - Executes docker-compose ps to show service status
# - Displays service status, ports, and uptime
# - Checks health of PostgreSQL connection
# - Checks accessibility of API endpoints

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

# Function to check if Docker daemon is running
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running"
        echo "Please start Docker Desktop and try again."
        exit 1
    fi
}

# Function to check if docker-compose is available
check_docker_compose() {
    # Try docker compose (v2) first
    if docker compose version &> /dev/null; then
        DOCKER_COMPOSE="docker compose"
        return 0
    fi
    
    # Fall back to docker-compose (v1)
    if command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE="docker-compose"
        return 0
    fi
    
    print_error "docker-compose not found"
    exit 1
}

# Function to display service status
display_service_status() {
    echo "=========================================="
    echo "📊 Supabase Local - Service Status"
    echo "=========================================="
    echo ""
    
    print_info "Container Status:"
    echo ""
    
    # Execute docker-compose ps
    $DOCKER_COMPOSE ps
    
    echo ""
}

# Function to check PostgreSQL health
check_postgres_health() {
    print_info "Checking PostgreSQL connection..."
    
    # Check if postgres container is running
    if ! $DOCKER_COMPOSE ps postgres | grep -q "Up"; then
        print_error "PostgreSQL container is not running"
        return 1
    fi
    
    # Try to connect to PostgreSQL
    if $DOCKER_COMPOSE exec -T postgres pg_isready -U postgres &> /dev/null; then
        print_success "PostgreSQL is healthy and accepting connections"
        return 0
    else
        print_error "PostgreSQL is not accepting connections"
        return 1
    fi
}

# Function to check API endpoint accessibility
check_api_endpoint() {
    local name=$1
    local url=$2
    
    # Use curl if available, otherwise skip
    if ! command -v curl &> /dev/null; then
        print_warning "curl not found, skipping API endpoint checks"
        return 0
    fi
    
    # Try to connect to the endpoint
    if curl -s -f -o /dev/null --max-time 3 "$url" 2>/dev/null; then
        print_success "$name is accessible at $url"
        return 0
    else
        # Some endpoints may return 404 or other status codes but still be accessible
        # Check if we can at least connect
        if curl -s -o /dev/null --max-time 3 "$url" 2>/dev/null; then
            print_success "$name is accessible at $url"
            return 0
        else
            print_error "$name is not accessible at $url"
            return 1
        fi
    fi
}

# Function to check all API endpoints
check_api_endpoints() {
    echo ""
    print_info "Checking API endpoint accessibility..."
    echo ""
    
    # Check if curl is available
    if ! command -v curl &> /dev/null; then
        print_warning "curl not found, skipping API endpoint checks"
        print_info "Install curl to enable endpoint health checks"
        return 0
    fi
    
    # Check Studio
    check_api_endpoint "Studio (Web UI)" "http://localhost:3000"
    
    # Check API Gateway
    check_api_endpoint "API Gateway" "http://localhost:8095"
    
    # Check Auth API
    check_api_endpoint "Auth API" "http://localhost:9999/health"
    
    # Check PostgREST API
    check_api_endpoint "PostgREST API" "http://localhost:3001"
    
    # Check Realtime
    check_api_endpoint "Realtime" "http://localhost:4000"
    
    # Check Storage
    check_api_endpoint "Storage" "http://localhost:5000/status"
}

# Function to display service URLs
display_service_urls() {
    echo ""
    echo "=========================================="
    echo "📍 Service URLs and Ports"
    echo "=========================================="
    echo ""
    echo "  - Studio (Web UI):    http://localhost:3000"
    echo "  - API Gateway:        http://localhost:8095"
    echo "  - PostgreSQL:         localhost:5432"
    echo "  - Auth API:           http://localhost:9999"
    echo "  - PostgREST API:      http://localhost:3001"
    echo "  - Realtime:           http://localhost:4000"
    echo "  - Storage:            http://localhost:5000"
    echo ""
}

# Function to display helpful commands
display_commands() {
    echo "=========================================="
    echo "📚 Useful Commands"
    echo "=========================================="
    echo ""
    echo "  - View logs:          ./scripts/logs.sh"
    echo "  - View service logs:  ./scripts/logs.sh [service]"
    echo "  - Stop services:      ./scripts/stop.sh"
    echo "  - Restart services:   ./scripts/start.sh"
    echo ""
    echo "=========================================="
}

# Main execution
main() {
    check_docker
    check_docker_compose
    display_service_status
    check_postgres_health
    check_api_endpoints
    display_service_urls
    display_commands
}

# Run main function
main
