# Hướng Dẫn Chạy Supabase trong WSL

## Tổng Quan

Tài liệu này hướng dẫn cách chuyển Supabase từ Docker Desktop sang WSL với Docker native để tránh các vấn đề bất ổn của Docker Desktop.

## Yêu Cầu

- Windows 10/11 với WSL2
- Ubuntu trong WSL (đã cài đặt)
- Project đã được copy sang: `\\wsl.localhost\Ubuntu\home\novaseele\dev\repo\ArtHub`

## Cài Đặt Tự Động

### Bước 1: Deploy Supabase lên WSL

Chạy script PowerShell để tự động cài đặt Docker và khởi động Supabase:

```powershell
.\deploy-to-wsl.ps1
```

Script này sẽ:
1. Kiểm tra WSL
2. Copy setup script sang WSL
3. Cài đặt Docker trong WSL (nếu chưa có)
4. Cài đặt Docker Compose
5. Khởi động Docker service
6. Chạy `docker compose up -d` để khởi động Supabase

### Bước 2: Kiểm Tra Trạng Thái

```powershell
.\wsl-supabase.ps1 status
```

## Quản Lý Supabase

### Script PowerShell (Khuyến Nghị)

Sử dụng script `wsl-supabase.ps1` để quản lý:

```powershell
# Khởi động Supabase
.\wsl-supabase.ps1 start

# Dừng Supabase
.\wsl-supabase.ps1 stop

# Khởi động lại
.\wsl-supabase.ps1 restart

# Xem trạng thái
.\wsl-supabase.ps1 status

# Xem logs (real-time)
.\wsl-supabase.ps1 logs

# Kiểm tra health
.\wsl-supabase.ps1 health

# Mở shell trong WSL
.\wsl-supabase.ps1 shell
```

### Lệnh Trực Tiếp trong WSL

Mở WSL và truy cập project:

```bash
wsl -d Ubuntu
cd /home/novaseele/dev/repo/ArtHub/supabase-local
```

Các lệnh Docker Compose:

```bash
# Khởi động
docker compose up -d

# Dừng
docker compose down

# Khởi động lại
docker compose restart

# Xem status
docker compose ps

# Xem logs
docker compose logs -f

# Xem logs của service cụ thể
docker compose logs -f postgres
docker compose logs -f studio
docker compose logs -f kong

# Dừng và xóa volumes
docker compose down -v
```

## Endpoints

Sau khi khởi động thành công:

- **Supabase Studio**: http://localhost:3000
- **Kong API Gateway**: http://localhost:8095
- **PostgreSQL**: localhost:5432
  - User: `postgres`
  - Password: `your-super-secret-password`
  - Database: `postgres`

## Kết Nối Backend NestJS

Backend NestJS vẫn chạy trên Windows, kết nối đến PostgreSQL trong WSL qua `localhost:5432`.

File `.env` của backend không cần thay đổi:

```env
DATABASE_URL="postgresql://postgres:your-super-secret-password@localhost:5432/postgres"
PORT=8080
NODE_ENV=development
```

## Khắc Phục Sự Cố

### Docker service không khởi động

```bash
wsl -d Ubuntu
sudo service docker start
```

### Permission denied khi chạy Docker

```bash
# Thêm user vào docker group
sudo usermod -aG docker $USER

# Áp dụng thay đổi
newgrp docker

# Hoặc logout và login lại WSL
exit
wsl -d Ubuntu
```

### Port đã được sử dụng

Kiểm tra process đang dùng port:

```bash
# Trong WSL
sudo lsof -i :3000
sudo lsof -i :5432
sudo lsof -i :8095

# Kill process nếu cần
sudo kill -9 <PID>
```

### Containers không khởi động

Xem logs chi tiết:

```bash
docker compose logs
```

Khởi động lại từ đầu:

```bash
docker compose down -v
docker compose up -d
```

### WSL hết RAM

Tạo file `.wslconfig` trong `C:\Users\<YourUsername>\`:

```ini
[wsl2]
memory=4GB
processors=2
swap=2GB
```

Sau đó restart WSL:

```powershell
wsl --shutdown
wsl -d Ubuntu
```

## Lợi Ích của WSL

1. **Ổn định hơn**: Docker native trong Linux ổn định hơn Docker Desktop
2. **Hiệu năng tốt hơn**: Không qua lớp virtualization của Docker Desktop
3. **Tài nguyên**: Kiểm soát tài nguyên tốt hơn
4. **Tích hợp**: Dễ dàng chạy scripts Linux

## Backup và Restore

### Backup Database

```bash
cd /home/novaseele/dev/repo/ArtHub/supabase-local
bash scripts/backup.sh
```

### Restore Database

```bash
bash scripts/restore.sh backups/<backup-file>.sql
```

## Tự Động Khởi Động

### Tạo Windows Task Scheduler

1. Mở Task Scheduler
2. Create Task
3. Trigger: At log on
4. Action: Start a program
   - Program: `powershell.exe`
   - Arguments: `-File "C:\path\to\wsl-supabase.ps1" start`

### Hoặc tạo shortcut

Tạo file `.bat`:

```batch
@echo off
powershell -ExecutionPolicy Bypass -File "C:\path\to\wsl-supabase.ps1" start
```

## Monitoring

### Xem resource usage

```bash
# Trong WSL
docker stats

# Xem disk usage
docker system df
```

### Health check script

```bash
cd /home/novaseele/dev/repo/ArtHub/supabase-local
python scripts/health_check.py
```

## Ghi Chú

- WSL2 chia sẻ network với Windows, nên `localhost` hoạt động bình thường
- Docker volumes được lưu trong WSL filesystem
- Backup thường xuyên để tránh mất dữ liệu
- Có thể truy cập files WSL từ Windows qua `\\wsl.localhost\Ubuntu\`

## Tài Liệu Tham Khảo

- [Docker in WSL2](https://docs.docker.com/desktop/wsl/)
- [WSL Documentation](https://docs.microsoft.com/en-us/windows/wsl/)
- [Supabase Self-Hosting](https://supabase.com/docs/guides/self-hosting)
