# Supabase trong WSL - Quick Reference

## ✅ Trạng Thái: Đang Chạy

Supabase đã được deploy thành công trong WSL với Docker native.

## Lệnh Nhanh

### Quản Lý (PowerShell)

```powershell
.\wsl-supabase.ps1 start    # Khởi động
.\wsl-supabase.ps1 stop     # Dừng
.\wsl-supabase.ps1 status   # Xem trạng thái
.\wsl-supabase.ps1 logs     # Xem logs
.\wsl-supabase.ps1 health   # Kiểm tra health
```

### Endpoints

- Studio: http://localhost:3000
- PostgreSQL: localhost:5432
- API: http://localhost:8095

### Backend Connection

```env
DATABASE_URL="postgresql://postgres:your-super-secret-password@localhost:5432/postgres"
```

## Tài Liệu

- **HUONG_DAN_WSL.md**: Hướng dẫn chi tiết
- **WSL_DEPLOYMENT_SUCCESS.md**: Thông tin deployment
- **wsl-supabase.ps1**: Script quản lý

## Khởi Động Backend

```powershell
cd nestjs-backend
npm run start:dev
# Backend: http://localhost:8080
# Swagger: http://localhost:8080/docs
```

## Troubleshooting

```bash
# Restart Docker service
wsl -d Ubuntu
sudo service docker restart

# Restart Supabase
.\wsl-supabase.ps1 restart

# Xem logs
.\wsl-supabase.ps1 logs
```

---

**Deployment Date**: 2026-03-29  
**Status**: ✅ Production Ready
