#!/bin/bash

# Script tự động cài đặt Docker trong WSL và chạy Supabase
# Author: Kiro AI Assistant
# Date: 2026-03-29

set -e  # Exit on error

echo "=========================================="
echo "Cài Đặt Docker trong WSL và Chạy Supabase"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Kiểm tra quyền root
if [ "$EUID" -eq 0 ]; then 
   echo -e "${RED}Không chạy script này với sudo!${NC}"
   echo "Chạy: bash setup-wsl-docker.sh"
   exit 1
fi

echo -e "${YELLOW}Bước 1: Kiểm tra Docker...${NC}"
# Kiểm tra Docker native (không phải Docker Desktop)
if command -v docker &> /dev/null && docker --version 2>&1 | grep -v "Docker Desktop" | grep -q "Docker version"; then
    echo -e "${GREEN}✓ Docker native đã được cài đặt${NC}"
    docker --version
elif [ -f "/usr/bin/dockerd" ] || [ -f "/usr/local/bin/dockerd" ]; then
    echo -e "${GREEN}✓ Docker đã được cài đặt${NC}"
else
    echo -e "${YELLOW}Docker native chưa được cài đặt. Đang cài đặt...${NC}"
    
    # Cập nhật package list
    echo "Cập nhật package list..."
    sudo apt-get update
    
    # Cài đặt dependencies
    echo "Cài đặt dependencies..."
    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Thêm Docker GPG key
    echo "Thêm Docker GPG key..."
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Thêm Docker repository
    echo "Thêm Docker repository..."
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Cài đặt Docker Engine
    echo "Cài đặt Docker Engine..."
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Thêm user vào docker group
    echo "Thêm user vào docker group..."
    sudo usermod -aG docker $USER
    
    # Khởi động Docker service
    echo "Khởi động Docker service..."
    sudo service docker start
    
    echo -e "${GREEN}✓ Docker đã được cài đặt thành công${NC}"
fi

echo -e "${YELLOW}Bước 2: Kiểm tra Docker Compose...${NC}"
# Kiểm tra với sudo nếu user chưa có quyền
if docker compose version &> /dev/null; then
    echo -e "${GREEN}✓ Docker Compose đã sẵn sàng${NC}"
    docker compose version
elif sudo docker compose version &> /dev/null; then
    echo -e "${YELLOW}! Docker Compose cần sudo, đang cấu hình quyền...${NC}"
    # Thêm user vào docker group nếu chưa có
    if ! groups $USER | grep -q docker; then
        sudo usermod -aG docker $USER
        echo -e "${YELLOW}! Đã thêm user vào docker group${NC}"
    fi
    # Khởi động lại docker service
    sudo service docker restart
    sleep 2
    echo -e "${GREEN}✓ Docker Compose đã sẵn sàng (với sudo)${NC}"
    sudo docker compose version
else
    echo -e "${RED}✗ Docker Compose không khả dụng${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Bước 3: Khởi động Docker service...${NC}"
if sudo service docker status | grep -q "running"; then
    echo -e "${GREEN}✓ Docker service đang chạy${NC}"
else
    echo "Khởi động Docker service..."
    sudo service docker start
    sleep 2
    echo -e "${GREEN}✓ Docker service đã được khởi động${NC}"
fi

echo ""
echo -e "${YELLOW}Bước 4: Kiểm tra project directory...${NC}"
PROJECT_DIR="/home/novaseele/dev/repo/ArtHub/supabase-local"
if [ -d "$PROJECT_DIR" ]; then
    echo -e "${GREEN}✓ Project directory tồn tại: $PROJECT_DIR${NC}"
    cd "$PROJECT_DIR"
else
    echo -e "${RED}✗ Project directory không tồn tại: $PROJECT_DIR${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Bước 5: Kiểm tra file cấu hình...${NC}"
if [ -f "docker-compose.yml" ]; then
    echo -e "${GREEN}✓ docker-compose.yml tồn tại${NC}"
else
    echo -e "${RED}✗ docker-compose.yml không tồn tại${NC}"
    exit 1
fi

if [ -f ".env" ]; then
    echo -e "${GREEN}✓ .env tồn tại${NC}"
else
    echo -e "${YELLOW}! .env không tồn tại, copy từ .env.example${NC}"
    cp .env.example .env
    echo -e "${GREEN}✓ Đã tạo .env từ .env.example${NC}"
fi

echo ""
echo -e "${YELLOW}Bước 6: Dọn dẹp containers cũ (nếu có)...${NC}"
# Sử dụng sudo nếu cần
DOCKER_CMD="docker"
if ! docker ps &> /dev/null; then
    DOCKER_CMD="sudo docker"
fi

if $DOCKER_CMD ps -a 2>/dev/null | grep -q "supabase-local"; then
    echo "Dừng và xóa containers cũ..."
    $DOCKER_CMD compose down -v 2>/dev/null || sudo docker compose down -v 2>/dev/null || true
    echo -e "${GREEN}✓ Đã dọn dẹp containers cũ${NC}"
else
    echo -e "${GREEN}✓ Không có containers cũ${NC}"
fi

echo ""
echo -e "${YELLOW}Bước 7: Khởi động Supabase với Docker Compose...${NC}"
echo "Đang pull images và khởi động services..."
# Thử không sudo trước, nếu fail thì dùng sudo
if docker compose up -d 2>/dev/null; then
    echo -e "${GREEN}✓ Đã khởi động với docker (không sudo)${NC}"
else
    echo -e "${YELLOW}Đang khởi động với sudo...${NC}"
    sudo docker compose up -d
fi

echo ""
echo -e "${YELLOW}Bước 8: Chờ services khởi động...${NC}"
sleep 10

echo ""
echo -e "${YELLOW}Bước 9: Kiểm tra trạng thái containers...${NC}"
if docker compose ps 2>/dev/null; then
    : # Success
else
    sudo docker compose ps
fi

echo ""
echo -e "${GREEN}=========================================="
echo "✓ Hoàn Thành Cài Đặt!"
echo "==========================================${NC}"
echo ""
echo "Thông tin truy cập:"
echo "  - Supabase Studio: http://localhost:3000"
echo "  - PostgreSQL: localhost:5432"
echo "  - Kong API Gateway: http://localhost:8095"
echo ""
echo "Lệnh hữu ích:"
echo "  - Xem logs: docker compose logs -f"
echo "  - Dừng services: docker compose down"
echo "  - Khởi động lại: docker compose restart"
echo "  - Xem status: docker compose ps"
echo ""
echo -e "${YELLOW}Lưu ý: Nếu gặp lỗi permission, chạy:${NC}"
echo "  newgrp docker"
echo "  hoặc logout và login lại WSL"
echo ""
