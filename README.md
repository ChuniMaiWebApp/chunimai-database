# chunimai-database

Hạ tầng dữ liệu và cấu hình máy chủ cho [ChuniMaiWebApp](https://github.com/ChuniMaiWebApp).
Repo này **không chứa code ứng dụng** và không chứa migration.

| Thư mục | Nội dung |
|---|---|
| `docker-compose.prod.yml` | Postgres, Redis, postgres-meta, Studio — bốn container chạy thật |
| `postgres/init/` | Script khởi tạo database, chạy một lần trên volume rỗng |
| `nginx/` | Ba vhost (`chunithm-app`, `chunithm-api`, `my-db`) và phần dùng chung |
| `scripts/` | Cài VPS, deploy, backup, cập nhật dải IP Cloudflare |
| `dev-stack/` | Supabase đầy đủ cho máy local — **không** dùng ở production |
| `dev-redis/` | Redis cho máy local (Windows/WSL) |

**Đọc trước:** [SYSTEM_OVERVIEW.md](SYSTEM_OVERVIEW.md) — mỗi thứ trên server
là gì, để làm gì, đụng vào khi nào. Không có code.

Cần lệnh cụ thể thì sang [PRODUCTION_DEPLOYMENT_GUIDE.md](PRODUCTION_DEPLOYMENT_GUIDE.md).

## Vì sao migration không nằm ở đây

Migration ở `chuni-backend/migrations/`, cạnh code đọc chúng. Tách ra thì mỗi
lần deploy thành hai lần push phải đúng thứ tự — sai thứ tự là schema lệch
code, và không có gì bắt được lỗi đó trước khi người chơi gặp.

## Vì sao production không chạy Supabase đầy đủ

Backend nói chuyện thẳng với Postgres qua `pg`. Thứ duy nhất từng gọi Supabase
là một dòng trạng thái trong `/health`. Kong, GoTrue, PostgREST, Realtime và
Storage đều không có mặt — khoảng 1 GB RAM cho những dịch vụ không ai gọi.

Studio thì vẫn giữ, vì bạn cần xem database qua trình duyệt. Nó chạy trực tiếp
với `postgres-meta`: Table Editor và SQL Editor hoạt động bình thường, các tab
Authentication/Storage/API Docs thì trống. Chi tiết ở mục 7 của guide.

## Lệnh hay dùng

```bash
# Trên VPS
docker compose -f docker-compose.prod.yml --env-file .env.prod ps
docker compose -f docker-compose.prod.yml --env-file .env.prod logs -f postgres
docker compose -f docker-compose.prod.yml --env-file .env.prod exec postgres psql -U postgres

./scripts/deploy.sh        # đồng bộ container, báo nếu nginx config đã đổi
./scripts/backup-db.sh     # dump ra backups/, giữ 14 ngày
```

```powershell
# Trên máy local (từ D:\Work\ChuniMaiWebApp)
npm run infra:up
npm run infra:status
npm run redis:start
```
