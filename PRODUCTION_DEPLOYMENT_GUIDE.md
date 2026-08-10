# Triển khai production — ChuniMaiWebApp

VPS `163.61.72.134` · Cloudflare (`novaseele.com`) · nginx · PM2 · GitHub Actions · Telegram

```
                    Internet
                       │
                  Cloudflare  (proxied, Full Strict)
          ┌────────────┼────────────┐
          ▼            ▼            ▼
   chunithm-app   chunithm-api    my-db
          │            │            │
          └────────────┴────────────┘
                    nginx  (163.61.72.134:443)
          │            │            │
          ▼            ▼            ▼
   Nuxt :3100     Nest :3333    Studio :3010
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

Ba repo, ba workflow, ba lần deploy độc lập. Sửa UI không đụng tới API; đổi
compose không build lại gì cả. Khi thêm maimai về sau, thêm `maimai-backend`
và `maimai-frontend` cạnh đây, dùng chung Postgres/Redis/Studio của repo này.

---

## ⚠️ 0. Làm trước tiên — mật khẩu root đã lộ

Mật khẩu root đã được dán vào một khung chat. Kể cả không ai đọc trộm, VPS đang
mở port 22 với đăng nhập bằng mật khẩu — bot dò quét IP mới liên tục.

```bash
ssh root@163.61.72.134
passwd
```

Rồi bỏ hẳn đăng nhập bằng mật khẩu. Trên **máy của bạn**:

```bash
ssh-keygen -t ed25519 -C "chunimai-deploy" -f ~/.ssh/chunimai_deploy
```

Trên **VPS** (vẫn đang là root):

```bash
adduser --gecos "" deploy
usermod -aG sudo deploy
mkdir -p /home/deploy/.ssh && chmod 700 /home/deploy/.ssh
nano /home/deploy/.ssh/authorized_keys      # dán nội dung ~/.ssh/chunimai_deploy.pub
chmod 600 /home/deploy/.ssh/authorized_keys
chown -R deploy:deploy /home/deploy/.ssh

mkdir -p /home/repo/ChuniMaiWebApp
chown -R deploy:deploy /home/repo
```

**Mở một cửa sổ SSH thứ hai** bằng `ssh -i ~/.ssh/chunimai_deploy deploy@163.61.72.134`
và xác nhận vào được, **trước khi** chạy bước dưới — nếu không bạn sẽ tự khoá
mình ra ngoài:

```bash
sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/'          /etc/ssh/sshd_config
sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh
```

Từ đây trở đi mọi lệnh chạy dưới user `deploy`, và `VPS_USERNAME` trong GitHub
Secrets là `deploy` chứ không phải `root`.

---

## 1. Đưa code lên GitHub

Ba thư mục local đã là ba git repo riêng, đang ở nhánh `master`, chưa có
remote. GitHub mặc định `main` nên đổi tên nhánh cho khớp — các workflow chỉ
lắng nghe `main`.

Chạy trên máy bạn, tại `D:\Work\ChuniMaiWebApp`:

```bash
cd chuni-backend
git branch -M main
git remote add origin https://github.com/ChuniMaiWebApp/chuni-backend.git
git add -A
git status          # ĐỌC KỸ: không được thấy .env, *.pem, *.key
git commit -m "Production deployment: trust proxy, cookie domain, optional Supabase, CI"
git push -u origin main
```

```bash
cd ../chuni-frontend
git branch -M main
git remote add origin https://github.com/ChuniMaiWebApp/chuni-frontend.git
git add -A
git status
git commit -m "Production deployment: split API base for SSR, stable fetch keys, lamp fixes"
git push -u origin main
```

`chunimai-database` chưa phải repo — khởi tạo mới:

```bash
cd ../chunimai-database
git init -b main
git add -A
git status          # KHÔNG được thấy .env.prod, dev-stack/volumes/, *.pem, *.key
git commit -m "Infrastructure: compose, nginx, VPS scripts, deployment guide"
git remote add origin https://github.com/ChuniMaiWebApp/chunimai-database.git
git push -u origin main
```

Cả ba nên để **private**. Không repo nào chứa secret, nhưng `chuni-backend` có
toàn bộ logic đăng nhập CHUNITHM-NET.

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

Script cài Node 22, PM2 (kèm logrotate), Docker, nginx, UFW, fail2ban, tạo swap
2 GB, tải CA origin-pull của Cloudflare, và đăng ký PM2 vào systemd. Chạy lại
nhiều lần không sao.

Xong thì **đăng xuất và SSH lại** để có quyền docker.

### Chứng chỉ và nginx

```bash
sudo nano /etc/ssl/cloudflare/origin.pem     # dán origin.pem
sudo nano /etc/ssl/cloudflare/origin.key     # dán origin.key
sudo chmod 600 /etc/ssl/cloudflare/origin.key

cd /home/repo/ChuniMaiWebApp/chunimai-database
sudo cp nginx/http-globals.conf      /etc/nginx/conf.d/chunimai-globals.conf
sudo cp nginx/cloudflare-realip.conf /etc/nginx/conf.d/
sudo cp nginx/snippets-proxy.conf    /etc/nginx/snippets/chunimai-proxy.conf
sudo cp nginx/chunithm-api.conf /etc/nginx/sites-available/chunithm-api
sudo cp nginx/chunithm-app.conf /etc/nginx/sites-available/chunithm-app
sudo cp nginx/my-db.conf        /etc/nginx/sites-available/my-db
sudo ln -sf /etc/nginx/sites-available/chunithm-api /etc/nginx/sites-enabled/
sudo ln -sf /etc/nginx/sites-available/chunithm-app /etc/nginx/sites-enabled/
sudo ln -sf /etc/nginx/sites-available/my-db        /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx
```

`cloudflare-realip.conf` **bắt buộc**, không phải tuỳ chọn. Thiếu nó thì mọi
request mang IP của Cloudflare edge, và bộ giới hạn đăng nhập tính theo IP sẽ
gộp toàn bộ người chơi vào chung một rổ: 10 lượt đăng nhập từ bất kỳ ai là
người thứ 11 bị khoá 15 phút.

### Điền secret

```bash
cd /home/repo/ChuniMaiWebApp

cp chunimai-database/.env.prod.example chunimai-database/.env.prod
nano chunimai-database/.env.prod
#   POSTGRES_PASSWORD=<openssl rand -hex 24>
#   Dùng hex chứ đừng base64: ký tự / và + phải percent-encode trong DATABASE_URL.

cp chuni-backend/.env.production.example chuni-backend/.env
nano chuni-backend/.env
#   DATABASE_URL=postgresql://postgres:<đúng mật khẩu trên>@127.0.0.1:5432/postgres
#   ENCRYPTION_KEY=<openssl rand -base64 32>
#   JWT_SECRET=<openssl rand -base64 32>
#   CORS_ORIGIN và COOKIE_DOMAIN đã điền sẵn đúng domain, kiểm tra lại là được.
```

`chuni-frontend` **không cần** `.env` — hai URL API nằm trong
`ecosystem.config.js` của nó.

> ⚠️ `ENCRYPTION_KEY` giải mã cookie jar CHUNITHM-NET của **mọi** người chơi.
> Mất nó thì tất cả phải liên kết lại tài khoản; lộ nó thì người khác thao tác
> được trên CHUNITHM-NET dưới danh nghĩa họ, kể cả đổi tên tài khoản. Backup
> riêng, đừng để chung chỗ với dump database.

### Chạy lần đầu, đúng thứ tự này

```bash
cd /home/repo/ChuniMaiWebApp/chunimai-database && ./scripts/deploy.sh
cd ../chuni-backend  && chmod +x scripts/deploy.sh && ./scripts/deploy.sh --first-run
cd ../chuni-frontend && chmod +x scripts/deploy.sh && ./scripts/deploy.sh --first-run
```

Database trước, vì API chạy migration lúc deploy và sẽ dừng lại nếu Postgres
chưa lên. Frontend sau cùng, vì trang render sẵn ở server cần API trả lời.

Nạp danh mục bài hát lần đầu (khoảng 7 800 chart):

```bash
cd /home/repo/ChuniMaiWebApp/chuni-backend
npm run seed:refresh
npm run seed:regions
```

Sau đó cron trong app tự làm mới lúc 08:00 UTC hằng ngày.

### Backup

```bash
crontab -e
```

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
curl -s https://chunithm-app.novaseele.com/ | grep -c "ChunithmQueue"

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
| Log | `pm2 logs chuni-backend --lines 100` |
| Trạng thái | `pm2 status` |
| Health | `curl -s localhost:3333/api/v1/health \| jq` |
| Data services | `cd chunimai-database && docker compose -f docker-compose.prod.yml --env-file .env.prod ps` |
| Deploy tay | `cd <repo> && ./scripts/deploy.sh` |
| Backup tay | `chunimai-database/scripts/backup-db.sh` |
| Quay về commit cũ | `git reset --hard <sha> && ./scripts/deploy.sh` |
| Vào DB bằng CLI | `docker compose -f docker-compose.prod.yml --env-file .env.prod exec postgres psql -U postgres` |

Deploy tự rollback: nếu health check không xanh trong 60 giây, script trả commit
cũ về, build lại và reload. Migration **không** bị hoàn tác — chúng chỉ thêm,
nên bản build cũ vẫn chạy được với schema mới.

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
