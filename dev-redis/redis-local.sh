#!/bin/bash

# Redis Local Management Script (similar to Supabase local)
# Usage: ./redis-local.sh [start|stop|restart|status|monitor|logs|cli|info|ping|data|keys|get|view]

REDIS_CONF="/etc/redis/redis.conf"
REDIS_PID_FILE="/var/run/redis/redis-server.pid"
REDIS_LOG_FILE="/var/log/redis/redis-server.log"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

show_redis_data() {
    echo ""
    echo -e "${CYAN}Redis Data Overview${NC}"
    echo -e "${CYAN}===================${NC}"
    echo ""
    
    # Get all keys
    local total_count=$(redis-cli --scan | wc -l)
    echo -e "${GREEN}Total Keys: $total_count${NC}"
    echo ""
    
    # Group by pattern
    declare -A patterns=(
        ["Rate Limiting"]="rate_limit:*"
        ["Blocked IPs"]="blocked_ip:*"
        ["Image Tokens"]="image_token:*"
        ["Processed Images"]="image:processed:*"
        ["Risk Scores"]="risk_score:*"
        ["Test Keys"]="test:*"
    )
    
    for name in "${!patterns[@]}"; do
        local pattern="${patterns[$name]}"
        local count=$(redis-cli --scan --pattern "$pattern" | wc -l)
        if [ "$count" -gt 0 ]; then
            echo -e "${YELLOW}$name: ${WHITE}$count keys${NC}"
        fi
    done
    
    echo ""
    echo -e "${CYAN}Quick Commands:${NC}"
    echo -e "  ${WHITE}./redis-local.sh keys              - List all keys${NC}"
    echo -e "  ${WHITE}./redis-local.sh keys rate_limit:* - List keys by pattern${NC}"
    echo -e "  ${WHITE}./redis-local.sh get <key>         - Get key value${NC}"
    echo -e "  ${WHITE}./redis-local.sh view              - View formatted data${NC}"
    echo ""
}

get_redis_keys() {
    local pattern="${1:-*}"
    echo -e "${YELLOW}Fetching Redis keys...${NC}"
    echo ""
    
    local keys=$(redis-cli --scan --pattern "$pattern")
    local key_count=$(echo "$keys" | wc -l)
    
    echo -e "${CYAN}Found $key_count keys${NC}"
    echo ""
    
    echo "$keys" | while read -r key; do
        echo -e "  ${WHITE}- $key${NC}"
    done
}

get_redis_key_value() {
    local key="$1"
    if [ -z "$key" ]; then
        echo -e "${RED}Error: Please provide a key name${NC}"
        echo -e "${YELLOW}Usage: ./redis-local.sh get <key>${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Getting value for key: $key${NC}"
    echo ""
    
    local value=$(redis-cli GET "$key")
    local ttl=$(redis-cli TTL "$key")
    
    echo -e "${CYAN}Key: ${WHITE}$key${NC}"
    echo -e "${CYAN}Value: ${WHITE}$value${NC}"
    echo -n -e "${CYAN}TTL: ${NC}"
    
    if [ "$ttl" = "-1" ]; then
        echo -e "${GREEN}No expiration${NC}"
    elif [ "$ttl" = "-2" ]; then
        echo -e "${RED}Key does not exist${NC}"
    else
        echo -e "${YELLOW}$ttl seconds${NC}"
    fi
}

show_redis_data_formatted() {
    echo -e "${YELLOW}Opening formatted Redis data viewer...${NC}"
    echo ""
    
    if [ -f "nestjs-backend/view-redis-data.js" ]; then
        cd nestjs-backend
        node view-redis-data.js
        cd ..
    else
        echo -e "${RED}Error: view-redis-data.js not found${NC}"
        echo -e "${YELLOW}Please run from the project root directory${NC}"
    fi
}

case "$1" in
  start)
    echo "Starting Redis server..."
    sudo service redis-server start
    sleep 2
    if sudo service redis-server status | grep -q "is running"; then
      echo -e "${GREEN}✓ Redis server started successfully${NC}"
      echo -e "  ${CYAN}- Host: localhost${NC}"
      echo -e "  ${CYAN}- Port: 6379${NC}"
      echo -e "  ${CYAN}- Monitor: ${WHITE}./redis-local.sh monitor${NC}"
      echo -e "  ${CYAN}- CLI: ${WHITE}./redis-local.sh cli${NC}"
    else
      echo -e "${RED}✗ Failed to start Redis server${NC}"
      exit 1
    fi
    ;;
    
  stop)
    echo "Stopping Redis server..."
    sudo service redis-server stop
    sleep 1
    echo -e "${GREEN}✓ Redis server stopped${NC}"
    ;;
    
  restart)
    echo "Restarting Redis server..."
    sudo service redis-server restart
    sleep 2
    if sudo service redis-server status | grep -q "is running"; then
      echo -e "${GREEN}✓ Redis server restarted successfully${NC}"
    else
      echo -e "${RED}✗ Failed to restart Redis server${NC}"
      exit 1
    fi
    ;;
    
  status)
    sudo service redis-server status
    ;;
    
  monitor)
    echo -e "${YELLOW}Starting Redis monitor (Ctrl+C to exit)...${NC}"
    echo ""
    redis-cli monitor
    ;;
    
  logs)
    echo -e "${YELLOW}Viewing Redis logs (Ctrl+C to exit)...${NC}"
    echo ""
    sudo journalctl -u redis-server -f
    ;;
    
  cli)
    echo -e "${YELLOW}Opening Redis CLI (type 'exit' to quit)...${NC}"
    echo ""
    redis-cli
    ;;
    
  info)
    redis-cli info
    ;;
    
  ping)
    echo -e "${YELLOW}Testing Redis connection...${NC}"
    result=$(redis-cli ping)
    if [ "$result" = "PONG" ]; then
      echo -e "${GREEN}✓ Redis is responding: $result${NC}"
    else
      echo -e "${RED}✗ Redis is not responding${NC}"
    fi
    ;;
    
  data)
    show_redis_data
    ;;
    
  keys)
    get_redis_keys "$2"
    ;;
    
  get)
    get_redis_key_value "$2"
    ;;
    
  view)
    show_redis_data_formatted
    ;;
    
  *)
    echo ""
    echo -e "${CYAN}Redis Local Management${NC}"
    echo -e "${CYAN}======================${NC}"
    echo ""
    echo "Usage: $0 [command] [args]"
    echo ""
    echo -e "${YELLOW}Server Commands:${NC}"
    echo -e "  ${GREEN}start   ${NC} - Start Redis server"
    echo -e "  ${GREEN}stop    ${NC} - Stop Redis server"
    echo -e "  ${GREEN}restart ${NC} - Restart Redis server"
    echo -e "  ${GREEN}status  ${NC} - Check Redis server status"
    echo -e "  ${GREEN}ping    ${NC} - Test Redis connection"
    echo ""
    echo -e "${YELLOW}Data Commands:${NC}"
    echo -e "  ${GREEN}data    ${NC} - Show Redis data overview"
    echo -e "  ${GREEN}keys    ${NC} [pattern] - List all keys (or by pattern)"
    echo -e "  ${GREEN}get     ${NC} <key> - Get value of a specific key"
    echo -e "  ${GREEN}view    ${NC} - View formatted data (Node.js)"
    echo ""
    echo -e "${YELLOW}Monitoring Commands:${NC}"
    echo -e "  ${GREEN}monitor ${NC} - Monitor Redis commands in real-time"
    echo -e "  ${GREEN}logs    ${NC} - View Redis logs"
    echo -e "  ${GREEN}cli     ${NC} - Open Redis CLI"
    echo -e "  ${GREEN}info    ${NC} - Show Redis server info"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "  ${WHITE}./redis-local.sh start${NC}"
    echo -e "  ${WHITE}./redis-local.sh data${NC}"
    echo -e "  ${WHITE}./redis-local.sh keys${NC}"
    echo -e "  ${WHITE}./redis-local.sh keys rate_limit:*${NC}"
    echo -e "  ${WHITE}./redis-local.sh get test:string${NC}"
    echo -e "  ${WHITE}./redis-local.sh view${NC}"
    echo -e "  ${WHITE}./redis-local.sh monitor${NC}"
    echo ""
    exit 1
    ;;
esac

exit 0
