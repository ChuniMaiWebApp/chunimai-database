# Triển khai production — ChuniMaiWebApp

VPS `163.61.72.134` · Cloudflare (`novaseele.com`) · nginx · Docker · GitHub Actions · Telegram

> **Đã triển khai và đang chạy.** Tài liệu này vừa là nhật ký những gì đã làm,
> vừa là hướng dẫn để dựng lại từ đầu. Trạng thái hiện tại ở [mục 9](#9-trạng-thái-hiện-tại).

```
                    Internet
                       │
                  Cloudflare  (proxied, Full)
          ┌────────────┼────────────┐
          ▼            ▼            ▼
   chunithm-app   chunithm-api    my-db
          │            │            │
          └────────────┴────────────┘
                    nginx  (163.61.72.134:443)
          │            │            │
          ▼            ▼            ▼
   Nuxt :3100     Nest :3333    Studio :3010
   (container)    (container)   (container)
          │            │            │
          └───SSR──────┤            ▼
                       ▼      postgres-meta
              Postgres :5432 ◀──────┘
              Redis    :6379

/home/repo/ChuniMaiWebApp/
├── chuni-backend/       → github.com/ChuniMaiWebApp/chuni-backend
├── chuni-frontend/      → github.com/ChuniMaiWebApp/chuni-frontend
└── chunimai-database/   → github.com/ChuniMaiWebApp/chunimai-database   (repo này)
```

Cả sáu tiến trình chạy trong Docker, mỗi repo một `docker-compose.yml`, dùng
chung một bridge tên `chunimai`. nginx là thứ duy nhất chạy thẳng trên host —
nó cần cổng 80/443 và các chứng chỉ trong `/etc/ssl`.

Ba repo, ba workflow, ba lần deploy độc lập. Sửa UI không đụng tới API; đổi
compose không build lại gì cả. Khi thêm maimai về sau, thêm `maimai-backend`
và `maimai-frontend` cạnh đây, dùng chung Postgres/Redis/Studio của repo này.

---

## ⚠️ 0. Bảo mật SSH — phần bạn còn phải làm

**Đã làm:** user `deploy` (không có mật khẩu, chỉ vào được bằng key), sudo
không cần mật khẩu, `/home/repo/ChuniMaiWebApp` thuộc về nó, fail2ban đang
chạy. Key ở `C:\Users\NovaSeele\.ssh\chunimai_deploy` — **hãy backup nó.**

Một chi tiết đáng nhớ nếu dựng lại: `adduser --disabled-password` trên Ubuntu
24.04 ghi `!` vào `/etc/shadow`, và sshd coi đó là *account locked* nên chặn cả
đăng nhập bằng key. Phải `usermod -p '*' deploy` — `*` nghĩa là "không mật khẩu
nào khớp được", khác với "khoá tài khoản".

**Chưa làm, cần bạn quyết định** — làm sai là tự khoá mình ra ngoài, nên tôi
không tự ý làm:

```bash
ssh root@163.61.72.134
passwd
```

Rồi tắt hẳn đăng nhập bằng mật khẩu. **Mở một cửa sổ SSH thứ hai và xác nhận
vào được bằng key trước đã:**

```bash
ssh -i ~/.ssh/chunimai_deploy deploy@163.61.72.134
```

Vào được rồi mới chạy:

```bash
sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/'          /etc/ssh/sshd_config
sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh
```

Từ đây trở đi mọi lệnh chạy dưới user `deploy`, và `VPS_USERNAME` trong GitHub
Secrets là `deploy` chứ không phải `root`.

---

## 1. GitHub — đã xong

Ba repo đã có đủ code, đang ở nhánh `master`. Workflow lắng nghe cả `main` lẫn
`master` nên không bắt buộc đổi tên. Muốn đổi cho chuẩn:

```bash
git branch -M main && git push -u origin main
# rồi đổi default branch trong Settings của repo, xoá nhánh master cũ
```

Quy trình hằng ngày từ giờ, trong repo tương ứng:

```bash
git add . && git commit -m "..." && git push
```

Actions sẽ lint → test → build → SSH vào VPS chạy `scripts/deploy.sh` → health
check → nhắn Telegram.

Hai điều đã cắn một lần, đừng để cắn lại:

- **Line ending.** `.gitattributes` ghim LF cho `*.sh`, `*.conf`, `*.yml`,
  `.env*`. Không có nó, Windows commit CRLF và Linux trả lời
  `bad interpreter: /usr/bin/env bash^M`; tệ hơn, `POSTGRES_PASSWORD=abc\r`
  khiến `\r` thành một phần mật khẩu và không khớp `DATABASE_URL`.
- **Bit thực thi.** `scripts/*.sh` được commit ở mode `100755`. Trước đó là
  `100644`, mà `deploy.sh` lại tự `git reset --hard` — nên mỗi lần deploy nó
  tự xoá quyền chạy của chính mình.

`chuni-backend` và `chuni-frontend` đang **public**. Không repo nào chứa secret
(`.env` bị gitignore, đã kiểm chứng bằng `git check-ignore`), nhưng
`chuni-backend` có toàn bộ logic đăng nhập CHUNITHM-NET — cân nhắc để private.

---

## 2. Cloudflare

DNS đã xong — ba bản ghi A đều Proxied. Còn lại:

1. **SSL/TLS → Overview** → chọn **Full (Strict)**.
2. **SSL/TLS → Origin Server → Create Certificate** (RSA 2048, mặc định).
   Lưu *Origin Certificate* thành `origin.pem`, *Private Key* thành
   `origin.key`. Cửa sổ private key **chỉ hiện một lần**.
3. **SSL/TLS → Origin Server → Authenticated Origin Pulls** → bật.
   Đây là thứ khiến ai gõ thẳng `163.61.72.134` không vào được `my-db`.
4. **Speed → Optimization** → tắt **Rocket Loader** nếu đang bật. App có một
   inline script chạy trước first paint để áp theme; Rocket Loader làm nó chạy
   trễ và gây nháy sai theme.

### Cloudflare Access cho `my-db` (bắt buộc)

Studio bản self-host **không có đăng nhập**. Ai mở được trang là đọc/ghi được
mọi bảng — kể cả `app.chunithm_links`, nơi chứa cookie jar CHUNITHM-NET đã mã
hoá của **mọi** người chơi. Để trần còn tệ hơn lộ mật khẩu database.

**Zero Trust → Access → Applications → Add an application → Self-hosted**

| Trường | Giá trị |
|---|---|
| Application name | `ChuniMai Studio` |
| Session duration | `24 hours` |
| Subdomain / Domain | `my-db` / `novaseele.com` |

Policy: `Action: Allow`, `Include → Emails → dpmai.mt360@gmail.com`.
Miễn phí tới 50 người dùng, đăng nhập bằng mã một lần gửi qua email.

Ba lớp bảo vệ, mỗi lớp một mình đã đủ:

1. **mTLS** — nginx đòi client certificate ký bởi CA origin-pull của Cloudflare,
   nên request bỏ qua Cloudflare bị từ chối ngay ở bước bắt tay TLS. Đây là
   thứ khiến lớp 2 không thể né được.
2. **Cloudflare Access** — chặn người lạ ở tầng Cloudflare.
3. **HTTP Basic** — có sẵn trong `nginx/my-db.conf`, đang comment. Bật nếu bạn
   không muốn dùng Zero Trust; để nguyên nếu đã cấu hình Access, không thì mỗi
   lần vào phải nhập hai lần mật khẩu.

---

## 3. GitHub Secrets

Sáu secret, thêm vào **cả ba repo** (`Settings → Secrets and variables → Actions`):

| Secret | Giá trị |
|---|---|
| `VPS_HOST` | `163.61.72.134` |
| `VPS_USERNAME` | `deploy` |
| `VPS_SSH_KEY` | **toàn bộ** nội dung `~/.ssh/chunimai_deploy`, kể cả dòng `-----BEGIN…` và `-----END…` |
| `VPS_PORT` | `22` |
| `TELEGRAM_BOT_TOKEN` | token từ @BotFather |
| `TELEGRAM_CHAT_ID` | id từ @userinfobot |

Kiểm tra Telegram trước khi đưa vào CI:

```bash
curl -s "https://api.telegram.org/bot<TOKEN>/sendMessage" -d "chat_id=<CHAT_ID>" -d "text=test"
```

Thấy `"ok":true` là được. Nhớ bấm Start và nhắn cho bot của bạn một câu trước —
bot Telegram không gửi được vào cuộc trò chuyện chưa từng được mở.

---

## 4. Cài đặt VPS

```bash
ssh -i ~/.ssh/chunimai_deploy deploy@163.61.72.134

cd /home/repo/ChuniMaiWebApp
git clone https://github.com/ChuniMaiWebApp/chunimai-database.git
git clone https://github.com/ChuniMaiWebApp/chuni-backend.git
git clone https://github.com/ChuniMaiWebApp/chuni-frontend.git

cd chunimai-database
chmod +x scripts/*.sh
./scripts/vps-setup.sh
```

Script cài Node 22, Docker (+ tạo bridge `chunimai`), nginx, UFW, fail2ban, tạo
swap 2 GB và tải CA origin-pull của Cloudflare. Chạy lại nhiều lần không sao.

Xong thì **đăng xuất và SSH lại** để có quyền docker.

### Chứng chỉ và nginx

Hiện tại đang dùng **self-signed cert** do tôi sinh trên VPS, hợp lệ 10 năm,
phủ `novaseele.com` và `*.novaseele.com`. Nó đủ để chạy với Cloudflare ở chế độ
**Full** (mã hoá chặng Cloudflare ↔ VPS nhưng không xác thực chứng chỉ). Muốn
lên **Full (Strict)** thì thay bằng Origin Certificate của Cloudflare:

```bash
sudo nano /etc/ssl/cloudflare/origin.pem     # dán Origin Certificate
sudo nano /etc/ssl/cloudflare/origin.key     # dán Private Key
sudo chmod 600 /etc/ssl/cloudflare/origin.key
sudo nginx -t && sudo systemctl reload nginx
# rồi Cloudflare → SSL/TLS → Overview → Full (Strict)
```

nginx đã cài sẵn; lệnh dựng lại từ đầu:

```bash
cd /home/repo/ChuniMaiWebApp/chunimai-database
sudo cp nginx/http-globals.conf      /etc/nginx/conf.d/chunimai-globals.conf
sudo cp nginx/cloudflare-realip.conf /etc/nginx/conf.d/
sudo mkdir -p /etc/nginx/snippets
sudo cp nginx/snippets-proxy.conf    /etc/nginx/snippets/chunimai-proxy.conf
sudo cp nginx/chunithm-api.conf /etc/nginx/sites-available/chunithm-api
sudo cp nginx/chunithm-app.conf /etc/nginx/sites-available/chunithm-app
sudo cp nginx/my-db.conf        /etc/nginx/sites-available/my-db
sudo ln -sf /etc/nginx/sites-available/chunithm-api /etc/nginx/sites-enabled/
sudo ln -sf /etc/nginx/sites-available/chunithm-app /etc/nginx/sites-enabled/
# my-db KHÔNG bật cho tới khi Cloudflare Access xong — xem mục 2.
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx
```

> Ubuntu 24.04 chạy nginx 1.24. Chỉ thị `http2 on;` đứng riêng là cú pháp của
> 1.25.1 trở lên và sẽ làm `nginx -t` fail với `unknown directive "http2"` —
> các file config ở đây dùng dạng `listen 443 ssl http2;`, chạy được cả hai.

`cloudflare-realip.conf` **bắt buộc**, không phải tuỳ chọn. Thiếu nó thì mọi
request mang IP của Cloudflare edge, và bộ giới hạn đăng nhập tính theo IP sẽ
gộp toàn bộ người chơi vào chung một rổ: 10 lượt đăng nhập từ bất kỳ ai là
người thứ 11 bị khoá 15 phút.

### Điền secret

Đã sinh và điền sẵn trên VPS — mật khẩu Postgres, `ENCRYPTION_KEY` và
`JWT_SECRET` được sinh bằng `openssl` **ngay trên máy đó**, ghi thẳng vào file,
không đi qua bất kỳ đâu khác. Cả hai file ở chế độ `600`.

Nếu dựng lại từ đầu:

```bash
cd /home/repo/ChuniMaiWebApp
umask 077

PG_PASS=$(openssl rand -hex 24)     # hex, không phải base64: ký tự / và +
                                    # phải percent-encode trong DATABASE_URL
sed -e "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${PG_PASS}|" \
    chunimai-database/.env.prod.example > chunimai-database/.env.prod

sed -e "s|^DATABASE_URL=.*|DATABASE_URL=postgresql://postgres:${PG_PASS}@postgres:5432/postgres|" \
    -e "s|^ENCRYPTION_KEY=.*|ENCRYPTION_KEY=$(openssl rand -base64 32)|" \
    -e "s|^JWT_SECRET=.*|JWT_SECRET=$(openssl rand -base64 32)|" \
    chuni-backend/.env.production.example > chuni-backend/.env

unset PG_PASS
chmod 600 chunimai-database/.env.prod chuni-backend/.env
```

Host trong `DATABASE_URL` là `postgres`, **không phải** `127.0.0.1`: API chạy
trong container, và loopback ở đó là loopback của chính container. `postgres`
và `redis` là alias trên bridge `chunimai`.

`chuni-frontend` **không cần** `.env` — hai URL API nằm trong
`docker-compose.yml` của nó.

> ⚠️ `ENCRYPTION_KEY` giải mã cookie jar CHUNITHM-NET của **mọi** người chơi.
> Mất nó thì tất cả phải liên kết lại tài khoản; lộ nó thì người khác thao tác
> được trên CHUNITHM-NET dưới danh nghĩa họ, kể cả đổi tên tài khoản. Backup
> riêng, đừng để chung chỗ với dump database:
>
> ```bash
> grep -E '^(ENCRYPTION_KEY|JWT_SECRET)=' chuni-backend/.env
> ```

### Chạy lần đầu, đúng thứ tự này

```bash
docker network create chunimai       # vps-setup.sh đã làm; idempotent

cd /home/repo/ChuniMaiWebApp/chunimai-database && ./scripts/deploy.sh
cd ../chuni-backend  && ./scripts/deploy.sh
cd ../chuni-frontend && ./scripts/deploy.sh
```

Database trước, vì API chạy migration lúc deploy và sẽ dừng lại nếu Postgres
chưa lên. Frontend sau cùng, vì trang render sẵn ở server cần API trả lời.

Danh mục bài hát **tự nạp** — scheduler trong API thấy database trống và chạy
catch-up ngay khi khởi động (2265 bài, 8234 chart, kèm cờ vùng intl/jp). Muốn
ép chạy lại:

```bash
cd chuni-backend
docker compose run --rm migrate npm run seed:refresh -- --force
docker compose run --rm migrate npm run seed:regions
```

Sau đó cron trong app tự làm mới lúc 08:00 UTC hằng ngày.

### Backup

Đã cài sẵn trong crontab của user `deploy`. Xem bằng `crontab -l`:

```cron
15 19 * * * /home/repo/ChuniMaiWebApp/chunimai-database/scripts/backup-db.sh >> /home/repo/ChuniMaiWebApp/chunimai-database/logs/backup.log 2>&1
0 4 1 * *   /home/repo/ChuniMaiWebApp/chunimai-database/scripts/update-cloudflare-ips.sh >> /home/repo/ChuniMaiWebApp/chunimai-database/logs/cloudflare-ips.log 2>&1
```

19:15 UTC = 02:15 giờ Việt Nam — sau khi tiệm game đóng cửa, trước lần refresh
08:00 UTC. Dump nằm cùng ổ đĩa nên chỉ cứu được lỗi migration, không cứu được
VPS chết: định kỳ tải `backups/` về máy.

---

## 5. Kiểm tra sau khi lên

```bash
# 1. Ba domain trả lời
curl -s https://chunithm-api.novaseele.com/api/v1/health | jq
curl -s -o /dev/null -w "%{http_code}\n" https://chunithm-app.novaseele.com
curl -s -o /dev/null -w "%{http_code}\n" https://my-db.novaseele.com     # 302 → Cloudflare Access

# 2. SSR thật sự chạy — HTML đầu tiên phải có nội dung
curl -s https://chunithm-app.novaseele.com/ | grep -c "ChunithmWebApp"

# 3. Cookie phiên: Domain=.novaseele.com, Secure, HttpOnly, SameSite=Lax
curl -sI -X POST https://chunithm-api.novaseele.com/api/v1/auth/login \
  -H 'Content-Type: application/json' -d '{"username":"x","password":"y"}' | grep -i set-cookie

# 4. Rate limit tính theo IP thật. Gọi 11 lần: lần thứ 11 phải 429,
#    và bạn bè ở IP khác vẫn vào được bình thường.
for i in $(seq 1 11); do
  curl -s -o /dev/null -w "%{http_code} " -X POST https://chunithm-api.novaseele.com/api/v1/auth/login \
    -H 'Content-Type: application/json' -d '{"username":"x","password":"y"}'
done; echo

# 5. Swagger phải 404
curl -s -o /dev/null -w "%{http_code}\n" https://chunithm-api.novaseele.com/api/docs

# 6. Studio không vào được nếu bỏ qua Cloudflare (mTLS chặn ở bước bắt tay)
curl -sk --max-time 10 https://163.61.72.134 -H "Host: my-db.novaseele.com" -o /dev/null -w "%{http_code}\n"

# 7. Postgres, Redis, Studio không lộ ra ngoài
nmap -Pn -p 5432,6379,3010,3333,3100 163.61.72.134   # tất cả phải filtered/closed
```

---

## 6. Vận hành hằng ngày

Sửa code → `git push origin main` vào đúng repo → Actions tự lint, test, build,
SSH vào VPS chạy `scripts/deploy.sh`, health check, rồi nhắn Telegram — kể cả
khi hỏng ngay từ khâu CI.

| Việc | Lệnh |
|---|---|
| Log API | `cd chuni-backend && docker compose logs -f api` |
| Log web | `cd chuni-frontend && docker compose logs -f web` |
| Trạng thái mọi thứ | `docker ps` |
| Health | `curl -s localhost:3333/api/v1/health \| jq` |
| Khởi động lại một app | `cd chuni-backend && docker compose restart api` |
| Dừng / bật lại | `docker compose down` / `docker compose up -d` |
| Deploy tay | `cd <repo> && ./scripts/deploy.sh` |
| Chạy migration | `cd chuni-backend && docker compose run --rm migrate` |
| Vào DB bằng psql | `cd chunimai-database && docker compose -f docker-compose.prod.yml --env-file .env.prod exec postgres psql -U postgres` |
| Backup tay | `chunimai-database/scripts/backup-db.sh` |
| Dọn image cũ | `docker image prune -f` |
| Xem dung lượng Docker | `docker system df` |


Deploy tự rollback: script gắn tag `:rollback` cho image đang chạy **trước khi**
build cái mới, nên nếu health check không xanh trong 60 giây nó quay về image cũ
ngay, không phải biên dịch lại từ nguồn. Migration **không** bị hoàn tác —
chúng chỉ thêm, nên image cũ vẫn chạy được với schema mới.

---

## 7. Điều cần biết về Studio

Studio ở đây chạy với **postgres-meta**, không có Kong. Nghĩa là:

- ✅ **Table Editor**, **SQL Editor**, **Database → Tables/Roles/Extensions** —
  chạy bình thường, đây là phần bạn cần.
- ❌ **Authentication**, **Storage**, **Edge Functions**, **API Docs** — trống
  hoặc báo lỗi. Production không chạy GoTrue, Storage hay PostgREST, nên không
  có gì để hiển thị.

Đó là đánh đổi có chủ ý: 4 container thay vì 12, tiết kiệm khoảng 1 GB RAM cho
những dịch vụ mà backend chưa từng gọi tới. Nếu sau này thực sự cần PostgREST
hoặc GoTrue, thêm vào `docker-compose.prod.yml` cùng Kong rồi điền lại
`SUPABASE_URL` trong `chuni-backend/.env` — health check sẽ tự động báo cáo lại
mục đó.

Muốn dùng công cụ khác (DBeaver, pgAdmin trên máy bạn) thì mở tunnel, không cần
mở cổng:

```bash
ssh -i ~/.ssh/chunimai_deploy -L 5433:127.0.0.1:5432 deploy@163.61.72.134
```

Rồi trỏ vào `localhost:5433`.

---

## 8. Chưa làm, cân nhắc sau

- **Build trong CI thay vì trên VPS.** VPS có 6 GB nên hiện tại thoải mái, mỗi
  lần deploy tốn 3–6 phút. Nếu muốn xuống ~30 giây thì build artifact trong
  Actions rồi rsync xuống.
- **Content-Security-Policy.** Đang cố ý không bật: app có inline script áp
  theme trước first paint, CSP không kèm nonce sẽ chặn nó.
- **HSTS.** Đã viết sẵn trong `nginx/chunithm-app.conf`, đang comment. Bật sau
  khi domain chạy ổn định — trình duyệt nhớ suốt `max-age`, sai thì không gỡ
  nhanh được.
- **Uptime monitoring.** `/api/v1/health` trả `ok`/`degraded` kèm trạng thái
  từng dependency — cắm thẳng vào UptimeRobot là xong.

---

## 9. Trạng thái hiện tại

Triển khai lúc 2026-08-11, đã kiểm chứng từ ngoài internet.

### Đang chạy

| Container | Cổng (chỉ 127.0.0.1) | Vai trò |
|---|---|---|
| `chuni-frontend` | 3100 | Nuxt/Nitro |
| `chuni-backend` | 3333 | NestJS |
| `chunimai-postgres` | 5432 | supabase/postgres 15.1 |
| `chunimai-redis` | 6379 | Redis 7 |
| `chunimai-meta` | — | postgres-meta cho Studio |
| `chunimai-studio` | 3010 | Supabase Studio (**chưa mở ra ngoài**) |

Cả sáu `healthy`. Dữ liệu: 2265 bài, 8234 chart (6357 quốc tế / 6860 Nhật),
11 migration. Backup đầu tiên 322 KiB.

### Đã kiểm chứng

- `https://chunithm-app.novaseele.com` → 200, SSR có nội dung thật; tìm kiếm
  và filter chạy qua Cloudflare.
- `https://chunithm-api.novaseele.com/api/v1/health` → `{"status":"ok",
  "dependencies":{"postgres":"up","redis":"up"}}`.
- **IP thật**: nginx ghi log `116.96.45.105` — đúng IP người gọi, không phải
  Cloudflare edge. Đây là điều kiện để bộ giới hạn đăng nhập có ý nghĩa.
- **Rate limit**: 11 lần gọi `/auth/login` → `401 ×5` rồi `429 ×6`. Chặn ở lần
  thứ 6 vì hạn mức theo *tài khoản* là 5; hạn mức theo IP là 10.
- **CORS**: `access-control-allow-origin: https://chunithm-app.novaseele.com`
  kèm `allow-credentials: true`.
- `/api/docs` → 404.
- Cổng 5432, 6379, 3010, 3333, 3100 đều đóng từ internet.
- Dữ liệu sống sót qua một lần recreate container (named volume).

### Chưa làm

1. **Đổi mật khẩu root và tắt `PasswordAuthentication`** — mục 0.
2. **Origin Certificate + Full (Strict)** — đang chạy self-signed + Full. Chặng
   Cloudflare ↔ VPS đã mã hoá nhưng chưa được xác thực.
3. **`my-db` chưa bật.** Studio đang chạy nhưng nginx vhost chưa symlink. Bật
   sau khi xong Cloudflare Access (mục 2), rồi:
   ```bash
   sudo ln -sf /etc/nginx/sites-available/my-db /etc/nginx/sites-enabled/
   sudo nginx -t && sudo systemctl reload nginx
   ```
   Cần cả **Authenticated Origin Pulls** bật ở Cloudflare, vì `my-db.conf` có
   `ssl_verify_client on` — không bật thì mọi request bị từ chối ở bắt tay TLS.
4. **GitHub Secrets + Telegram** — chưa điền, nên push chưa tự deploy. Sáu
   secret ở mục 3.
5. **Cookie phiên chưa kiểm chứng thực tế.** `COOKIE_DOMAIN=.novaseele.com` đã
   nạp đúng vào container, nhưng `Set-Cookie` chỉ xuất hiện khi đăng nhập
   thành công — cần tài khoản SEGA thật. Đăng nhập lần đầu, mở DevTools →
   Application → Cookies và xác nhận `session` có `Domain=.novaseele.com`,
   `Secure`, `HttpOnly`, `SameSite=Lax`. Nếu thiếu `Domain`, SSR sẽ luôn render
   trạng thái chưa đăng nhập.
