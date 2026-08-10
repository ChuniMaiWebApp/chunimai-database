#!/usr/bin/env bash
#
# Logs script for Supabase Local Setup
# Compatible with Windows bash (Git Bash, WSL)
#
# This script:
# - Executes docker-compose logs with options
# - Supports filtering by service name
# - Displays logs with timestamps
# - Supports follow mode (-f)

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
    echo "Usage: $0 [OPTIONS] [SERVICE]"
    echo ""
    echo "Display logs from Supabase services"
    echo ""
    echo "Options:"
    echo "  -f, --follow      Follow log output (real-time)"
    echo "  -n, --tail NUM    Number of lines to show from the end (default: all)"
    echo "  -t, --timestamps  Show timestamps (enabled by default)"
    echo "  -h, --help        Display this help message"
    echo ""
    echo "Services:"
    echo "  postgres          PostgreSQL database"
    echo "  rest              PostgREST API"
    echo "  auth              GoTrue authentication"
    echo "  realtime          Realtime server"
    echo "  storage           Storage API"
    echo "  kong              Kong API Gateway"
    echo "  studio            Supabase Studio UI"
    echo ""
    echo "Examples:"
    echo "  $0                    # Show all logs"
    echo "  $0 -f                 # Follow all logs"
    echo "  $0 postgres           # Show PostgreSQL logs"
    echo "  $0 -f postgres        # Follow PostgreSQL logs"
    echo "  $0 -n 100 postgres    # Show last 100 lines of PostgreSQL logs"
    echo ""
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

# Function to validate service name
validate_service() {
    local service=$1
    local valid_services=("postgres" "rest" "auth" "realtime" "storage" "kong" "studio")
    
    for valid in "${valid_services[@]}"; do
        if [ "$service" = "$valid" ]; then
            return 0
        fi
    done
    
    print_error "Invalid service name: $service"
    echo ""
    echo "Valid services: ${valid_services[*]}"
    echo ""
    echo "Run '$0 --help' for more information."
    exit 1
}

# Function to display logs
display_logs() {
    local follow=$1
    local tail=$2
    local timestamps=$3
    local service=$4
    
    # Build docker-compose logs command
    local cmd="$DOCKER_COMPOSE logs"
    
    # Add timestamps (enabled by default)
    if [ "$timestamps" = "true" ]; then
        cmd="$cmd --timestamps"
    fi
    
    # Add follow mode
    if [ "$follow" = "true" ]; then
        cmd="$cmd --follow"
    fi
    
    # Add tail option
    if [ -n "$tail" ]; then
        cmd="$cmd --tail=$tail"
    fi
    
    # Add service filter
    if [ -n "$service" ]; then
        cmd="$cmd $service"
    fi
    
    # Display info message
    if [ -n "$service" ]; then
        print_info "Displaying logs for service: $service"
    else
        print_info "Displaying logs for all services"
    fi
    
    if [ "$follow" = "true" ]; then
        print_info "Following logs (press Ctrl+C to stop)..."
    fi
    
    echo ""
    
    # Execute the command
    eval "$cmd"
}

# Main execution
main() {
    # Parse command line arguments
    local follow="false"
    local tail=""
    local timestamps="true"
    local service=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--follow)
                follow="true"
                shift
                ;;
            -n|--tail)
                tail="$2"
                shift 2
                ;;
            -t|--timestamps)
                timestamps="true"
                shift
                ;;
            --no-timestamps)
                timestamps="false"
                shift
                ;;
            -h|--help)
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
                if [ -n "$service" ]; then
                    print_error "Multiple services specified. Please specify only one service."
                    echo ""
                    usage
                    exit 1
                fi
                service="$1"
                shift
                ;;
        esac
    done
    
    # Validate service name if provided
    if [ -n "$service" ]; then
        validate_service "$service"
    fi
    
    # Check prerequisites
    check_docker
    check_docker_compose
    
    # Display logs
    display_logs "$follow" "$tail" "$timestamps" "$service"
}

# Run main function
main "$@"
