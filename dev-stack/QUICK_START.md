# Hướng Dẫn Nhanh - Supabase Local

## Khởi Động Lần Đầu

### 1. Cấu hình môi trường
```bash
# Copy file .env.example thành .env
cp .env.example .env

# Chỉnh sửa .env và thay đổi các giá trị sau:
# - POSTGRES_PASSWORD: Mật khẩu database của bạn
# - JWT_SECRET: Chuỗi ngẫu nhiên ít nhất 32 ký tự
```

### 2. Khởi động Supabase
```bash
# Khởi động tất cả services
docker compose up -d

# Hoặc sử dụng script
./scripts/start.sh
```

### 3. Truy cập Studio
Mở trình duyệt và truy cập: **http://localhost:3000**

---

## Các Lệnh Thường Dùng

### Quản lý Services

```bash
# Khởi động
docker compose up -d

# Dừng (giữ lại data)
docker compose down

# Dừng và xóa tất cả (bao gồm data)
docker compose down -v

# Khởi động lại
docker compose restart

# Khởi động lại một service cụ thể
docker compose restart postgres
docker compose restart studio
```

### Kiểm tra trạng thái

```bash
# Xem trạng thái tất cả services
docker compose ps

# Hoặc dùng script
./scripts/status.sh

# Xem logs của tất cả services
docker compose logs

# Xem logs của một service cụ thể
docker compose logs postgres
docker compose logs studio
docker compose logs kong

# Follow logs real-time
docker compose logs -f
docker compose logs -f postgres
```

### Backup & Restore

```bash
# Backup database và storage
./scripts/backup.sh

# Backup chỉ database
./scripts/backup.sh --db-only

# Backup chỉ storage
./scripts/backup.sh --storage-only

# Restore từ backup
./scripts/restore.sh supabase_db_backup_20240101_120000.tar.gz

# Restore không cần xác nhận
./scripts/restore.sh --force backup_file.tar.gz
```

### Dọn dẹp

```bash
# Dọn dẹp containers (giữ data)
./scripts/cleanup.sh

# Dọn dẹp hoàn toàn (xóa cả data)
./scripts/cleanup.sh --volumes
```

---

## Truy Cập Services

| Service | URL | Mô tả |
|---------|-----|-------|
| **Studio** | http://localhost:3000 | Giao diện quản trị web |
| **API Gateway** | http://localhost:8095 | Kong Gateway - API endpoint chính |
| **PostgreSQL** | localhost:5432 | Database (user: postgres) |
| **PostgREST** | http://localhost:3001 | REST API |
| **Meta API** | http://localhost:8080 | Database metadata API |

---

## Kết Nối Database

### Từ command line (psql)
```bash
psql -h localhost -p 5432 -U postgres -d postgres
```

### Từ application code

**Node.js:**
```javascript
const { Client } = require('pg');
const client = new Client({
  host: 'localhost',
  port: 5432,
  user: 'postgres',
  password: 'your-password', // từ .env
  database: 'postgres'
});
```

**Python:**
```python
import psycopg2

conn = psycopg2.connect(
    host="localhost",
    port=5432,
    user="postgres",
    password="your-password",  # từ .env
    database="postgres"
)
```

### Sử dụng Supabase Client

```javascript
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  'http://localhost:8095',
  'YOUR_ANON_KEY'  // Lấy từ .env
);
```

---

## Troubleshooting

### Services không khởi động được

```bash
# Kiểm tra logs để xem lỗi
docker compose logs

# Kiểm tra ports có bị chiếm không
python scripts/check_ports.py

# Validate cấu hình
python scripts/validate_config.py

# Restart từ đầu
docker compose down -v
docker compose up -d
```

### Studio không load được

```bash
# Kiểm tra Kong Gateway
curl http://localhost:8095

# Kiểm tra Meta service
curl http://localhost:8095/pg/schemas

# Restart Studio
docker compose restart studio kong
```

### Database connection errors

```bash
# Kiểm tra PostgreSQL đang chạy
docker compose ps postgres

# Xem logs của PostgreSQL
docker compose logs postgres

# Test kết nối
psql -h localhost -p 5432 -U postgres -d postgres
```

---

## Tips & Tricks

### Xem resource usage
```bash
docker stats
```

### Xóa tất cả Docker resources (cẩn thận!)
```bash
docker system prune -a --volumes
```

### Export database
```bash
docker exec supabase-postgres pg_dump -U postgres postgres > backup.sql
```

### Import database
```bash
cat backup.sql | docker exec -i supabase-postgres psql -U postgres -d postgres
```

### Chạy SQL command trực tiếp
```bash
docker exec supabase-postgres psql -U postgres -d postgres -c "SELECT * FROM schema_migrations;"
```

---

## Cấu Trúc Thư Mục

```
supabase-local/
├── .env                    # Cấu hình môi trường
├── docker-compose.yml      # Định nghĩa services
├── kong.yml               # Cấu hình Kong Gateway
├── init-scripts/          # SQL scripts khởi tạo database
├── scripts/               # Các scripts tiện ích
│   ├── start.sh          # Khởi động
│   ├── stop.sh           # Dừng
│   ├── status.sh         # Kiểm tra trạng thái
│   ├── logs.sh           # Xem logs
│   ├── backup.sh         # Backup
│   ├── restore.sh        # Restore
│   └── cleanup.sh        # Dọn dẹp
├── backups/              # Thư mục chứa backup files
└── volumes/              # Data persistence (tự động tạo)
```

---

## Các Port Được Sử dụng

| Port | Service | Có thể thay đổi? |
|------|---------|------------------|
| 3000 | Studio | ✅ Có |
| 3001 | PostgREST | ✅ Có |
| 5432 | PostgreSQL | ✅ Có |
| 8095 | Kong Gateway | ✅ Có |
| 8080 | Meta API | ✅ Có |

Để thay đổi port, chỉnh sửa `docker-compose.yml`:
```yaml
ports:
  - "3001:3000"  # Thay 3001 thành port bạn muốn
```

---

## Lưu Ý Quan Trọng

⚠️ **Development Only**: Setup này chỉ dành cho môi trường development local, không dùng cho production.

⚠️ **Data Persistence**: Data được lưu trong Docker volumes. Chỉ xóa volumes khi bạn muốn reset hoàn toàn.

⚠️ **Security**: Đổi `POSTGRES_PASSWORD` và `JWT_SECRET` trong file `.env` trước khi sử dụng.

⚠️ **Backup**: Thường xuyên backup data quan trọng bằng `./scripts/backup.sh`.

---

## Tài Liệu Đầy Đủ

Xem file `README.md` để có hướng dẫn chi tiết hơn về:
- Cài đặt và cấu hình
- Troubleshooting chi tiết
- Tài liệu tham khảo
- Best practices
