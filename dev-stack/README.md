# Supabase Local Setup

Self-host Supabase trên máy local sử dụng Docker, cung cấp đầy đủ các dịch vụ của Supabase (PostgreSQL, Auth, Storage, Realtime, API) và giao diện quản trị web giống như phiên bản cloud.

## Prerequisites

Trước khi bắt đầu, đảm bảo hệ thống của bạn đáp ứng các yêu cầu sau:

### Docker

- **Docker Engine**: Phiên bản >= 20.10
- **Docker Compose**: Phiên bản >= 2.0

Kiểm tra phiên bản hiện tại:

```bash
docker --version
docker compose version
```

Nếu bạn chưa cài đặt Docker, tải về tại:
- **Windows/macOS**: [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- **Linux**: [Docker Engine](https://docs.docker.com/engine/install/)

### System Requirements

**Minimum:**
- **RAM**: 4 GB khả dụng
- **Disk Space**: 10 GB trống
- **CPU**: 2 cores

**Recommended:**
- **RAM**: 8 GB khả dụng
- **Disk Space**: 20 GB trống
- **CPU**: 4 cores

### Additional Requirements

- **Bash shell**: 
  - Linux/macOS: Có sẵn
  - Windows: Git Bash hoặc WSL (Windows Subsystem for Linux)
- **Python 3.6+**: (Optional) Để chạy validation và health check scripts
- **Ports**: Các ports sau phải available:
  - `3000` - Studio (Web UI)
  - `3001` - PostgREST (REST API)
  - `4000` - Realtime
  - `5000` - Storage API
  - `5432` - PostgreSQL
  - `8095` - Kong Gateway (host → container `8000`)
  - `9999` - GoTrue (Auth API)

Kiểm tra port availability:

```bash
python scripts/check_ports.py
```

## Setup Instructions

### Bước 1: Clone hoặc Download Project

**Option A: Clone từ Git repository**

```bash
git clone <repository-url>
cd supabase-local
```

**Option B: Download và giải nén**

1. Download file ZIP từ repository
2. Giải nén vào thư mục mong muốn
3. Mở terminal và di chuyển vào thư mục:

```bash
cd path/to/supabase-local
```

### Bước 2: Cấu Hình Environment Variables

Tạo file `.env` từ template và cấu hình các biến môi trường:

```bash
cp .env.example .env
```

Mở file `.env` và cập nhật các giá trị sau:

#### 2.1. Database Configuration

```bash
# Đặt password mạnh cho PostgreSQL
POSTGRES_PASSWORD=your-super-secret-password

# Giữ nguyên các giá trị mặc định (recommended)
POSTGRES_DB=postgres
POSTGRES_USER=postgres
```

#### 2.2. JWT Configuration

```bash
# Generate JWT secret (tối thiểu 32 ký tự)
# Sử dụng lệnh sau để tạo random string:
openssl rand -base64 32

# Paste vào file .env:
JWT_SECRET=<generated-secret-here>
```

#### 2.3. API Keys

File `.env.example` đã có sẵn demo keys. Để sử dụng production:

**Option A: Sử dụng demo keys (Development)**

Giữ nguyên giá trị `ANON_KEY` và `SERVICE_ROLE_KEY` trong `.env.example` (đã có sẵn).

**Option B: Generate custom keys (Production)**

```bash
# Sử dụng Supabase JWT generator hoặc script tùy chỉnh
# Đảm bảo keys được sign với JWT_SECRET của bạn
```

#### 2.4. API và Studio Configuration

```bash
# URL để truy cập API (giữ nguyên cho local development)
API_EXTERNAL_URL=http://localhost:8095

# Port cho Studio web UI (thay đổi nếu port 3000 đã được sử dụng)
STUDIO_PORT=3000
```

**Lưu ý quan trọng:**
- `JWT_SECRET` phải có độ dài tối thiểu 32 ký tự
- `SERVICE_ROLE_KEY` có quyền truy cập đầy đủ - không expose trong client-side code
- `ANON_KEY` an toàn để sử dụng trong client-side code với row-level security

### Bước 3: Validate Configuration

Trước khi khởi động, kiểm tra configuration files:

```bash
# Kiểm tra ports có available không
python scripts/check_ports.py

# Validate configuration files
python scripts/validate_config.py
```

Nếu có lỗi, script sẽ hiển thị hướng dẫn cụ thể để fix.

### Bước 4: Khởi Động Supabase Stack

Khởi động tất cả services:

```bash
./scripts/start.sh
```

Script sẽ:
1. Kiểm tra Docker daemon đang chạy
2. Validate configuration files
3. Pull Docker images (lần đầu tiên sẽ mất vài phút)
4. Khởi động tất cả services theo đúng thứ tự
5. Chờ health checks pass
6. Hiển thị URLs để truy cập services

**Lần đầu tiên khởi động:**
- Docker sẽ download các images (~2-3 GB)
- Quá trình có thể mất 5-10 phút tùy vào tốc độ internet
- Các lần sau sẽ nhanh hơn nhiều (chỉ vài giây)

### Bước 5: Verify Services

Sau khi khởi động thành công, kiểm tra trạng thái:

```bash
./scripts/status.sh
```

Truy cập các services:

- **Studio (Web UI)**: http://localhost:3000
- **API Gateway**: http://localhost:8095
- **Auth API**: http://localhost:9999

### Bước 6: Truy Cập Studio

1. Mở browser và truy cập: http://localhost:3000
2. Studio sẽ tự động kết nối với PostgreSQL local
3. Bạn có thể bắt đầu:
   - Tạo tables trong Table Editor
   - Chạy SQL queries trong SQL Editor
   - Quản lý authentication users
   - Upload files vào Storage

**Chúc mừng!** Supabase local của bạn đã sẵn sàng sử dụng. 🎉

## Common Commands

Dưới đây là các lệnh thường dùng để quản lý Supabase local stack:

### Start - Khởi Động Stack

Khởi động tất cả services:

```bash
./scripts/start.sh
```

Script này sẽ:
- Kiểm tra Docker daemon đang chạy
- Validate configuration files
- Khởi động tất cả containers
- Chờ health checks pass
- Hiển thị service URLs

### Stop - Dừng Stack

Dừng tất cả services (giữ lại data):

```bash
./scripts/stop.sh
```

Script này sẽ:
- Dừng tất cả containers
- Giữ lại volumes (data không bị mất)
- Giữ lại networks

**Lưu ý:** Data trong PostgreSQL và Storage sẽ được giữ lại và có thể sử dụng lại khi restart.

### Status - Kiểm Tra Trạng Thái

Xem trạng thái của tất cả services:

```bash
./scripts/status.sh
```

Output hiển thị:
- Tên service và container
- Trạng thái (running, stopped, unhealthy)
- Port mappings
- Uptime

### Logs - Xem Logs

**Xem logs của tất cả services:**

```bash
./scripts/logs.sh
```

**Xem logs của một service cụ thể:**

```bash
./scripts/logs.sh [service-name]
```

Ví dụ:

```bash
# Xem logs của PostgreSQL
./scripts/logs.sh postgres

# Xem logs của Kong Gateway
./scripts/logs.sh kong

# Xem logs của Studio
./scripts/logs.sh studio
```

**Các service names có sẵn:**
- `postgres` - PostgreSQL database
- `rest` - PostgREST API
- `auth` - GoTrue authentication
- `realtime` - Realtime subscriptions
- `storage` - Storage API
- `kong` - Kong Gateway
- `studio` - Studio web UI

**Follow logs real-time:**

```bash
# Follow tất cả logs
./scripts/logs.sh -f

# Follow logs của một service
./scripts/logs.sh -f postgres
```

### Cleanup - Dọn Dẹp Resources

**Cleanup cơ bản (giữ lại data):**

```bash
./scripts/cleanup.sh
```

Script này sẽ:
- Dừng và xóa tất cả containers
- Xóa networks
- Giữ lại volumes (data không bị mất)

**Cleanup hoàn toàn (xóa cả data):**

```bash
./scripts/cleanup.sh --volumes
```

⚠️ **Cảnh báo:** Lệnh này sẽ xóa tất cả data trong PostgreSQL và Storage. Không thể khôi phục!

Script này sẽ:
- Dừng và xóa tất cả containers
- Xóa networks
- Xóa volumes (tất cả data bị mất)

**Khi nào nên dùng cleanup:**
- `./scripts/cleanup.sh`: Khi muốn reset containers nhưng giữ lại data
- `./scripts/cleanup.sh --volumes`: Khi muốn bắt đầu lại từ đầu với database trống

### Backup - Sao Lưu Dữ Liệu

Tạo backup của PostgreSQL và Storage data volumes:

```bash
# Backup cả database và storage
./scripts/backup.sh

# Backup chỉ database
./scripts/backup.sh --db-only

# Backup chỉ storage
./scripts/backup.sh --storage-only
```

Script này sẽ:
- Tạo timestamped backup archives
- Lưu backups vào thư mục `./backups/`
- Hiển thị kích thước và vị trí của backup files

**Backup files:**
- `supabase_db_backup_YYYYMMDD_HHMMSS.tar.gz` - PostgreSQL data
- `supabase_storage_backup_YYYYMMDD_HHMMSS.tar.gz` - Storage data

**Lưu ý:** 
- Backup có thể thực hiện khi services đang chạy
- Backup files được nén với gzip để tiết kiệm dung lượng
- Mỗi backup có timestamp riêng để tránh ghi đè

### Restore - Khôi Phục Dữ Liệu

Khôi phục PostgreSQL và Storage data từ backup archives:

```bash
# Khôi phục từ backup (có confirmation prompt)
./scripts/restore.sh supabase_db_backup_20240101_120000.tar.gz

# Khôi phục với absolute path
./scripts/restore.sh /path/to/backup.tar.gz

# Khôi phục không cần confirmation (force)
./scripts/restore.sh --force supabase_storage_backup_20240101_120000.tar.gz

# Xem danh sách backups có sẵn
./scripts/restore.sh --help
```

Script này sẽ:
- Verify backup file integrity trước khi restore
- Tự động detect backup type (database hoặc storage)
- Stop các services liên quan trước khi restore
- Clear existing data và extract backup archive
- Verify restore thành công

**⚠️ Cảnh báo:**
- Restore sẽ **THAY THẾ HOÀN TOÀN** dữ liệu hiện tại
- Dữ liệu cũ sẽ bị mất vĩnh viễn
- Backup dữ liệu hiện tại trước khi restore nếu cần
- Script sẽ yêu cầu xác nhận trước khi thực hiện (trừ khi dùng `--force`)

**Sau khi restore:**
```bash
# Khởi động lại services
./scripts/start.sh

# Kiểm tra trạng thái
./scripts/status.sh
```

### Quick Reference

```bash
# Khởi động
./scripts/start.sh

# Dừng (giữ data)
./scripts/stop.sh

# Kiểm tra trạng thái
./scripts/status.sh

# Xem logs
./scripts/logs.sh [service]

# Backup dữ liệu
./scripts/backup.sh

# Restore dữ liệu
./scripts/restore.sh <backup_file>

# Dọn dẹp (giữ data)
./scripts/cleanup.sh

# Dọn dẹp hoàn toàn (xóa data)
./scripts/cleanup.sh --volumes
```


## Service URLs and Ports

Sau khi khởi động thành công, các services của Supabase sẽ accessible tại các địa chỉ sau:

### Web Interfaces

| Service | URL | Description |
|---------|-----|-------------|
| **Studio** | http://localhost:3000 | Giao diện web quản trị Supabase với Table Editor, SQL Editor, Authentication, và Storage management |

### API Endpoints

| Service | URL | Description |
|---------|-----|-------------|
| **API Gateway** | http://localhost:8095 | Kong Gateway - điểm truy cập chính cho tất cả API requests |
| **Auth API** | http://localhost:9999 | GoTrue Authentication API - quản lý user authentication và authorization |

### Database

| Service | Host | Port | Description |
|---------|------|------|-------------|
| **PostgreSQL** | localhost | 5432 | PostgreSQL database server - kết nối trực tiếp cho database clients |

### Internal Services

Các services sau chỉ accessible thông qua Kong Gateway (không expose trực tiếp):

- **PostgREST API**: Accessible qua `http://localhost:8095/rest/*`
- **Realtime API**: Accessible qua `http://localhost:8095/realtime/*`
- **Storage API**: Accessible qua `http://localhost:8095/storage/*`

### Connection Examples

**Kết nối PostgreSQL từ command line:**

```bash
psql -h localhost -p 5432 -U postgres -d postgres
```

**Kết nối PostgreSQL từ application:**

```javascript
// Node.js example
const { Client } = require('pg');
const client = new Client({
  host: 'localhost',
  port: 5432,
  user: 'postgres',
  password: process.env.POSTGRES_PASSWORD,
  database: 'postgres'
});
```

**Sử dụng Supabase Client:**

```javascript
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  'http://localhost:8095',
  'YOUR_ANON_KEY' // Lấy từ .env file
);
```

### Port Customization

Nếu bạn cần thay đổi ports (do conflicts hoặc preferences), chỉnh sửa file `docker-compose.yml`:

```yaml
services:
  studio:
    ports:
      - "3001:3000"  # Thay đổi port bên trái (host port)
  
  kong:
    ports:
      - "8095:8000"  # Host:container — mặc định hiện tại
  
  postgres:
    ports:
      - "5433:5432"  # Thay đổi port bên trái (host port)
```

**Lưu ý:** Sau khi thay đổi ports, cần cập nhật:
- File `.env` (nếu có biến môi trường liên quan)
- Connection strings trong application code
- Restart stack: `./scripts/stop.sh && ./scripts/start.sh`

### Kiểm Tra Port Availability

Trước khi khởi động, kiểm tra xem các ports có available không:

```bash
python scripts/check_ports.py
```

Script sẽ hiển thị:
- Ports nào đang available
- Ports nào đang được sử dụng
- Process nào đang sử dụng conflicting ports
- Hướng dẫn để giải phóng ports


## Troubleshooting

Dưới đây là các vấn đề thường gặp và cách giải quyết khi sử dụng Supabase local setup.

### Port Conflicts

**Triệu chứng:**
```
Error: Port 5432 is already in use
Error: Bind for 0.0.0.0:3000 failed: port is already allocated
```

**Nguyên nhân:** Port đã được sử dụng bởi process khác hoặc container Docker khác.

**Giải pháp:**

**Option 1: Kiểm tra và dừng process đang sử dụng port**

```bash
# Kiểm tra ports có available không
python scripts/check_ports.py

# Tìm process đang sử dụng port (Linux/macOS)
lsof -ti:5432

# Dừng process (thay 5432 bằng port bị conflict)
lsof -ti:5432 | xargs kill -9

# Windows (PowerShell)
netstat -ano | findstr :5432
taskkill /PID <PID> /F
```

**Option 2: Dừng containers Docker cũ**

```bash
# Dừng tất cả containers của Supabase
./scripts/stop.sh

# Hoặc dừng tất cả containers Docker
docker stop $(docker ps -aq)
```

**Option 3: Thay đổi port mappings**

Chỉnh sửa `docker-compose.yml` để sử dụng ports khác:

```yaml
services:
  postgres:
    ports:
      - "5433:5432"  # Thay đổi port bên trái (host port)
  
  studio:
    ports:
      - "3001:3000"  # Thay đổi port bên trái (host port)
```

Sau đó restart stack:

```bash
./scripts/stop.sh
./scripts/start.sh
```

---

### Docker Daemon Issues

**Triệu chứng:**
```
Error: Docker daemon is not running
Cannot connect to the Docker daemon at unix:///var/run/docker.sock
```

**Nguyên nhân:** Docker Desktop chưa được khởi động hoặc Docker daemon không chạy.

**Giải pháp:**

**Windows/macOS:**
1. Mở Docker Desktop application
2. Đợi cho đến khi Docker Desktop hiển thị "Docker is running"
3. Thử lại lệnh start

**Linux:**

```bash
# Kiểm tra status của Docker daemon
sudo systemctl status docker

# Khởi động Docker daemon
sudo systemctl start docker

# Enable Docker để tự động start khi boot
sudo systemctl enable docker
```

**Permission Issues (Linux):**

Nếu gặp lỗi "permission denied":

```bash
# Thêm user vào docker group
sudo usermod -aG docker $USER

# Logout và login lại để apply changes
# Hoặc chạy:
newgrp docker

# Verify
docker ps
```

---

### Health Check Failures

**Triệu chứng:**
```
Error: PostgreSQL health check failed after 60 seconds
Service 'postgres' is unhealthy
```

**Nguyên nhân:** Service không khởi động thành công hoặc mất quá nhiều thời gian để ready.

**Giải pháp:**

**Bước 1: Kiểm tra logs của service bị lỗi**

```bash
# Xem logs của PostgreSQL
./scripts/logs.sh postgres

# Xem logs của tất cả services
./scripts/logs.sh
```

**Bước 2: Kiểm tra trạng thái containers**

```bash
./scripts/status.sh
```

**Bước 3: Các nguyên nhân thường gặp và cách fix**

**A. Insufficient Memory**

PostgreSQL và các services khác cần ít nhất 4GB RAM available.

```bash
# Kiểm tra memory usage
docker stats

# Giải pháp: Tăng memory allocation cho Docker Desktop
# Settings → Resources → Memory → Tăng lên 6-8 GB
```

**B. Corrupted Data Volume**

```bash
# Dừng stack
./scripts/stop.sh

# Xóa volumes và bắt đầu lại từ đầu
./scripts/cleanup.sh --volumes

# Khởi động lại
./scripts/start.sh
```

**C. Invalid Configuration**

```bash
# Validate configuration files
python scripts/validate_config.py

# Fix các lỗi được báo và thử lại
```

**D. Network Issues**

```bash
# Kiểm tra network connectivity giữa containers
docker network inspect supabase-local_default

# Recreate network
./scripts/cleanup.sh
./scripts/start.sh
```

**Bước 4: Tăng timeout cho health checks**

Nếu máy chậm, có thể cần tăng timeout trong `docker-compose.yml`:

```yaml
services:
  postgres:
    healthcheck:
      interval: 10s
      timeout: 5s
      retries: 10  # Tăng từ 5 lên 10
```

---

### Volume Permission Issues

**Triệu chứng:**
```
Error: Permission denied: /var/lib/postgresql/data
PostgreSQL cannot write to data directory
mkdir: cannot create directory '/var/lib/postgresql/data': Permission denied
```

**Nguyên nhân:** Container không có quyền write vào volume directory trên host machine.

**Giải pháp:**

**Linux:**

```bash
# Dừng stack
./scripts/stop.sh

# Fix permissions cho PostgreSQL volume
# PostgreSQL container chạy với UID 999
sudo chown -R 999:999 ./volumes/db

# Fix permissions cho Storage volume
sudo chown -R 1000:1000 ./volumes/storage

# Khởi động lại
./scripts/start.sh
```

**macOS/Windows:**

Docker Desktop tự động handle permissions, nhưng nếu vẫn gặp vấn đề:

```bash
# Xóa volumes và tạo lại
./scripts/cleanup.sh --volumes
./scripts/start.sh
```

**SELinux Issues (Linux):**

Nếu sử dụng SELinux:

```bash
# Thêm SELinux context cho volumes
sudo chcon -Rt svirt_sandbox_file_t ./volumes/

# Hoặc disable SELinux (không khuyến khích)
sudo setenforce 0
```

---

### Configuration Errors

**Triệu chứng:**
```
Error: Missing required environment variable: JWT_SECRET
Error: Invalid YAML syntax in docker-compose.yml
```

**Nguyên nhân:** File `.env` hoặc `docker-compose.yml` bị thiếu hoặc có lỗi syntax.

**Giải pháp:**

**A. Missing .env file**

```bash
# Tạo .env từ template
cp .env.example .env

# Chỉnh sửa .env và điền các giá trị bắt buộc
nano .env  # hoặc vim, code, etc.
```

**B. Invalid environment variables**

```bash
# Validate .env file
python scripts/validate_config.py

# Đảm bảo JWT_SECRET có ít nhất 32 ký tự
openssl rand -base64 32
```

**C. YAML syntax errors**

```bash
# Validate YAML syntax
python -c "import yaml; yaml.safe_load(open('docker-compose.yml'))"

# Hoặc sử dụng online YAML validator
# https://www.yamllint.com/
```

---

### Service Connection Errors

**Triệu chứng:**
```
Error: PostgREST cannot connect to PostgreSQL
Error: Kong Gateway timeout
```

**Nguyên nhân:** Services không thể communicate với nhau qua Docker network.

**Giải pháy:**

**Bước 1: Kiểm tra network**

```bash
# List networks
docker network ls

# Inspect Supabase network
docker network inspect supabase-local_default

# Verify tất cả containers đều trong cùng network
```

**Bước 2: Test connectivity**

```bash
# Test từ PostgREST đến PostgreSQL
docker compose exec rest ping postgres

# Test DNS resolution
docker compose exec rest nslookup postgres
```

**Bước 3: Recreate network**

```bash
# Dừng và xóa tất cả
./scripts/cleanup.sh

# Khởi động lại (network sẽ được tạo mới)
./scripts/start.sh
```

---

### Image Pull Failures

**Triệu chứng:**
```
Error: failed to pull image "supabase/postgres:15.1.0.117"
Error: dial tcp: lookup registry-1.docker.io: no such host
```

**Nguyên nhân:** Không có kết nối internet hoặc Docker registry không accessible.

**Giải pháp:**

**A. Kiểm tra internet connection**

```bash
# Test connectivity
ping google.com

# Test Docker Hub
ping registry-1.docker.io
```

**B. Retry với timeout dài hơn**

```bash
# Pull images manually với retry
docker compose pull --ignore-pull-failures

# Sau đó start
./scripts/start.sh
```

**C. Sử dụng proxy (nếu cần)**

Thêm vào `~/.docker/config.json`:

```json
{
  "proxies": {
    "default": {
      "httpProxy": "http://proxy.example.com:8080",
      "httpsProxy": "http://proxy.example.com:8080"
    }
  }
}
```

---

### Studio UI Issues

**Triệu chứng:**
- Studio không load được
- Blank page tại http://localhost:3000
- "Cannot connect to database" error

**Giải pháp:**

**A. Kiểm tra Studio container**

```bash
# Xem logs của Studio
./scripts/logs.sh studio

# Kiểm tra status
./scripts/status.sh
```

**B. Verify Kong Gateway**

```bash
# Test Kong Gateway
curl http://localhost:8095

# Xem logs của Kong
./scripts/logs.sh kong
```

**C. Clear browser cache**

1. Mở Developer Tools (F12)
2. Right-click Refresh button → "Empty Cache and Hard Reload"
3. Hoặc thử incognito/private window

**D. Restart Studio container**

```bash
docker compose restart studio

# Đợi vài giây và thử lại
```

---

### Disk Space Issues

**Triệu chứng:**
```
Error: no space left on device
Error: failed to create container: disk quota exceeded
```

**Giải pháy:**

**Kiểm tra disk space:**

```bash
# Kiểm tra disk usage
df -h

# Kiểm tra Docker disk usage
docker system df
```

**Dọn dẹp Docker resources:**

```bash
# Xóa unused containers, images, volumes
docker system prune -a --volumes

# Cảnh báo: Lệnh này sẽ xóa TẤT CẢ unused Docker resources
# Backup data quan trọng trước!
```

**Giải phóng space cho Supabase:**

```bash
# Xóa chỉ Supabase volumes (mất data!)
./scripts/cleanup.sh --volumes

# Xóa unused Docker images
docker image prune -a
```

---

### General Debugging Tips

**1. Kiểm tra logs chi tiết:**

```bash
# Follow logs real-time
./scripts/logs.sh -f

# Xem logs của service cụ thể
./scripts/logs.sh postgres
./scripts/logs.sh kong
./scripts/logs.sh studio
```

**2. Kiểm tra trạng thái containers:**

```bash
# Xem status tất cả services
./scripts/status.sh

# Xem chi tiết container
docker compose ps -a
```

**3. Restart từng service:**

```bash
# Restart một service cụ thể
docker compose restart postgres
docker compose restart studio
```

**4. Complete reset:**

Nếu tất cả các cách trên không work:

```bash
# Dừng tất cả
./scripts/stop.sh

# Xóa hoàn toàn (bao gồm data!)
./scripts/cleanup.sh --volumes

# Validate configuration
python scripts/validate_config.py

# Khởi động lại từ đầu
./scripts/start.sh
```

**5. Kiểm tra system requirements:**

```bash
# RAM available
free -h  # Linux
vm_stat  # macOS

# CPU cores
nproc  # Linux
sysctl -n hw.ncpu  # macOS

# Docker version
docker --version
docker compose version
```

---

### Getting Help

Nếu vẫn gặp vấn đề sau khi thử các giải pháp trên:

1. **Collect diagnostic information:**
   ```bash
   # System info
   docker version
   docker compose version
   
   # Container status
   ./scripts/status.sh > debug-status.txt
   
   # Logs
   ./scripts/logs.sh > debug-logs.txt
   ```

2. **Check existing issues:**
   - Supabase GitHub Issues: https://github.com/supabase/supabase/issues
   - Docker GitHub Issues: https://github.com/docker/compose/issues

3. **Ask for help:**
   - Supabase Discord: https://discord.supabase.com
   - Stack Overflow: Tag với `supabase` và `docker-compose`

4. **Provide information khi báo lỗi:**
   - Operating system và version
   - Docker và Docker Compose versions
   - Error messages đầy đủ
   - Logs của services bị lỗi
   - Steps để reproduce issue


## Official Documentation Links

Tham khảo tài liệu chính thức để hiểu sâu hơn về các công nghệ và services được sử dụng trong Supabase local setup.

### Supabase

- **Supabase Official Documentation**: https://supabase.com/docs
  - Hướng dẫn đầy đủ về tất cả tính năng của Supabase
  - API reference và SDK documentation
  - Best practices và tutorials

- **Self-Hosting Guide**: https://supabase.com/docs/guides/self-hosting
  - Hướng dẫn chi tiết về self-hosting Supabase
  - Production deployment considerations
  - Configuration options

- **Supabase GitHub Repository**: https://github.com/supabase/supabase
  - Source code và Docker configurations
  - Community discussions và issues
  - Contributing guidelines

### Docker

- **Docker Documentation**: https://docs.docker.com/
  - Docker Engine installation và usage
  - Container management
  - Networking và volumes

- **Docker Compose Documentation**: https://docs.docker.com/compose/
  - Compose file reference
  - CLI commands
  - Best practices

- **Docker Compose File Reference**: https://docs.docker.com/compose/compose-file/
  - YAML syntax và options
  - Service configuration
  - Networks và volumes

### Individual Services

#### PostgreSQL

- **PostgreSQL Official Documentation**: https://www.postgresql.org/docs/
  - SQL reference và tutorials
  - Administration và configuration
  - Performance tuning

- **Supabase Postgres**: https://github.com/supabase/postgres
  - Supabase-specific PostgreSQL image
  - Pre-installed extensions
  - Configuration details

#### PostgREST

- **PostgREST Documentation**: https://postgrest.org/
  - API reference
  - Authentication và authorization
  - Query parameters và filtering

- **PostgREST GitHub**: https://github.com/PostgREST/postgrest
  - Source code
  - Configuration options
  - Troubleshooting

#### GoTrue (Authentication)

- **GoTrue Documentation**: https://github.com/supabase/gotrue
  - Authentication flows
  - API endpoints
  - Configuration options

- **Supabase Auth Documentation**: https://supabase.com/docs/guides/auth
  - User management
  - Social providers
  - Row Level Security (RLS)

#### Realtime

- **Supabase Realtime Documentation**: https://supabase.com/docs/guides/realtime
  - Real-time subscriptions
  - Broadcast và presence
  - WebSocket connections

- **Realtime GitHub**: https://github.com/supabase/realtime
  - Source code
  - Configuration
  - Protocol details

#### Storage

- **Supabase Storage Documentation**: https://supabase.com/docs/guides/storage
  - File uploads và downloads
  - Access control
  - Image transformations

- **Storage API GitHub**: https://github.com/supabase/storage-api
  - API reference
  - Configuration options
  - S3 compatibility

#### Kong Gateway

- **Kong Documentation**: https://docs.konghq.com/
  - Gateway configuration
  - Plugins và routing
  - Performance tuning

- **Kong Gateway (OSS)**: https://docs.konghq.com/gateway/latest/
  - Open-source version documentation
  - Declarative configuration
  - Admin API

### Additional Resources

- **Supabase Community**: https://github.com/supabase/supabase/discussions
  - Community discussions
  - Feature requests
  - Q&A

- **Supabase Discord**: https://discord.supabase.com
  - Real-time community support
  - Announcements
  - Networking với developers

- **Supabase Blog**: https://supabase.com/blog
  - Product updates
  - Technical articles
  - Case studies
