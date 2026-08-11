# Tổng quan hệ thống — ChuniMaiWebApp

Tài liệu này giải thích **mỗi thứ trên server là gì, để làm gì, và khi nào cần
đụng vào**. Không có code — chỗ nào cần lệnh cụ thể thì xem
[PRODUCTION_DEPLOYMENT_GUIDE.md](PRODUCTION_DEPLOYMENT_GUIDE.md).

Đọc một lần để nắm bản đồ. Khi có sự cố, mục [6](#6-hỏng-thì-xem-ở-đâu) là chỗ
bắt đầu.

---

## 1. Một request đi qua những đâu

```
Người chơi
   │
   ▼
Cloudflare          ← chống DDoS, cache ảnh/JS, giấu IP thật của VPS
   │                  (bản ghi DNS để Proxied = đám mây cam)
   ▼
nginx (trên VPS)    ← chốt chặn duy nhất mở ra internet, cổng 80/443
   │                  quyết định request thuộc domain nào, chuyển tiếp vào trong
   ├──────────────┬──────────────┐
   ▼              ▼              ▼
Nuxt :3100    NestJS :3333   Studio :3010
(giao diện)   (API)          (xem database)
                   │
                   ▼
            Postgres :5432   ← dữ liệu thật
            Redis    :6379   ← đếm số lần đăng nhập sai, khoá tác vụ định kỳ
```

**Điều quan trọng nhất cần nhớ:** tất cả cổng bên trong (3100, 3333, 3010,
5432, 6379) chỉ mở cho `127.0.0.1` — tức chỉ chính VPS gọi được. Người ngoài
internet **không** chạm tới được, kể cả biết IP. Đường vào duy nhất là nginx.

---

## 2. Quy trình đã thực hiện

Theo đúng thứ tự đã làm. Mỗi bước phụ thuộc bước trước.

| # | Bước | Vì sao cần |
|---|---|---|
| 1 | Tạo user `deploy`, đăng nhập bằng SSH key | Không thao tác bằng `root`. Key an toàn hơn mật khẩu tuyệt đối |
| 2 | Cài đặt môi trường (`vps-setup.sh`) | Docker, nginx, tường lửa, swap, chống dò mật khẩu SSH |
| 3 | Clone 3 repo về `/home/repo/ChuniMaiWebApp/` | Server lấy code từ GitHub, không upload tay |
| 4 | Sinh mật khẩu và khoá bí mật **ngay trên VPS** | Secret không đi qua chat, qua máy local, qua đâu cả |
| 5 | Tạo chứng chỉ TLS | Chặng Cloudflare ↔ VPS phải mã hoá — mật khẩu SEGA đi qua đó |
| 6 | Cấu hình nginx (3 domain) | Ai gọi domain nào thì vào đúng dịch vụ đó |
| 7 | Dựng Postgres + Redis + Studio | Phải có database trước, vì API chạy migration lúc khởi động |
| 8 | Dựng API (build image → migration → chạy) | |
| 9 | Dựng giao diện | Cuối cùng, vì trang render sẵn ở server cần API trả lời |
| 10 | Cài lịch backup tự động | |
| 11 | Kiểm tra từ ngoài internet | Chạy được trên VPS ≠ chạy được với người dùng thật |

Danh mục bài hát **không phải nạp tay** — API tự phát hiện database trống và
tải về ngay lần khởi động đầu tiên.

---

## 3. Bản đồ file

Chia làm hai nhóm, và **sự khác nhau này rất quan trọng**:

- **Nhóm A — trong repo:** deploy tự động cập nhật. Sửa ở máy, push, xong.
- **Nhóm B — trên VPS, ngoài git:** deploy **không** đụng tới. Muốn đổi phải
  SSH vào sửa tay. Cố ý như vậy: một job CI tự ghi đè `/etc` là cách nhanh
  nhất để sập cả site vì một lỗi chính tả.

### Nhóm A — file trong repo

#### `chunimai-database` (repo hạ tầng)

| File | Để làm gì |
|---|---|
| `docker-compose.prod.yml` | Định nghĩa 4 container dữ liệu: Postgres, Redis, và cặp postgres-meta + Studio |
| `postgres/init/01-init.sql` | Chạy **đúng một lần** khi database còn trắng. Tạo quyền và extension cần thiết |
| `.env.prod.example` | Bản mẫu. File thật `.env.prod` nằm trên VPS, không bao giờ vào git |
| `nginx/chunithm-app.conf` | Domain giao diện → Nuxt |
| `nginx/chunithm-api.conf` | Domain API → NestJS. Kèm phanh chống dò mật khẩu, chặn trang tài liệu API |
| `nginx/my-db.conf` | Domain Studio. **Đang tắt** — xem mục 7 |
| `nginx/cloudflare-realip.conf` | Khôi phục IP thật của người dùng. **Quan trọng bậc nhất** — xem mục 7 |
| `nginx/http-globals.conf` | Khai báo dùng chung: hạn mức gọi API, xử lý WebSocket |
| `nginx/snippets-proxy.conf` | Các header nginx gửi kèm khi chuyển tiếp vào trong |
| `scripts/vps-setup.sh` | Cài server mới từ số 0. Chạy lại nhiều lần không sao |
| `scripts/deploy.sh` | Đồng bộ container dữ liệu, báo nếu file nginx trong repo đã khác trên VPS |
| `scripts/backup-db.sh` | Dump database, nén, giữ 14 ngày. Từ chối xoá bản cũ nếu bản mới quá nhỏ |
| `scripts/update-cloudflare-ips.sh` | Cập nhật dải IP Cloudflare hằng tháng |
| `.github/workflows/deploy.yml` | Kiểm tra cấu hình rồi deploy khi push |
| `dev-stack/`, `dev-redis/` | **Chỉ dùng ở máy local.** Không liên quan production |

#### `chuni-backend` và `chuni-frontend`

| File | Để làm gì |
|---|---|
| `Dockerfile` | Công thức đóng gói ứng dụng thành image chạy được |
| `.dockerignore` | Chặn thứ không được vào image: `node_modules`, `.git`, và **`.env`** |
| `docker-compose.yml` | Chạy image đó: cổng nào, mạng nào, biến môi trường gì |
| `scripts/deploy.sh` | Toàn bộ một lần deploy — xem mục 4 |
| `.github/workflows/deploy.yml` | Chạy `deploy.sh` trên VPS khi push |
| `.env.production.example` | *(chỉ backend)* Bản mẫu cấu hình |
| `.gitattributes` | Ép xuống dòng kiểu Linux — xem mục 7 |

### Nhóm B — file trên VPS, ngoài git

| Đường dẫn | Là gì | Đụng vào khi nào |
|---|---|---|
| `/home/repo/ChuniMaiWebApp/chunimai-database/.env.prod` | Mật khẩu Postgres | Hầu như không bao giờ |
| `/home/repo/ChuniMaiWebApp/chuni-backend/.env` | **Toàn bộ secret của API** | Khi đổi domain hoặc xoay khoá |
| `/etc/ssl/cloudflare/origin.pem` + `.key` | Chứng chỉ TLS. Hiện là self-signed | Khi lên Full (Strict) |
| `/etc/ssl/cloudflare/origin-pull-ca.pem` | Chứng chỉ để kiểm tra request có thật sự đến từ Cloudflare | Khi bật `my-db` |
| `/etc/nginx/sites-enabled/` | Domain nào đang **bật**. Đây là nơi quyết định `my-db` sống hay chết | Khi bật/tắt một domain |
| `/etc/nginx/conf.d/`, `/etc/nginx/snippets/` | Bản copy của các file nginx trong repo | Khi repo đổi — copy tay |
| `/home/deploy/.ssh/authorized_keys` | Ai được vào server | Khi thêm/gỡ người |
| `/home/deploy/.ssh/github_deploy` | Khoá server dùng để kéo code | Không |
| `/etc/sudoers.d/90-deploy` | Cho `deploy` chạy sudo không cần mật khẩu | Không |
| `/swapfile` | 2 GB bộ nhớ ảo | Không |
| `crontab -l` của user `deploy` | Lịch backup + cập nhật IP Cloudflare | Khi đổi giờ backup |

> **Cạm bẫy dễ dính nhất:** sửa file trong `nginx/` của repo rồi push, và
> tưởng là đã áp dụng. **Không.** Deploy chỉ *báo* rằng file đã khác, bạn phải
> SSH vào copy tay rồi `nginx -t && systemctl reload nginx`.

---

## 4. Một lần deploy diễn ra thế nào

Bạn `git push` → GitHub Actions:

1. **Kiểm tra trước** — lint, test, build thử trên máy của GitHub. Hỏng ở đây
   thì **dừng, không đụng tới server**.
2. **SSH vào VPS**, chạy `scripts/deploy.sh` của repo đó.
3. `deploy.sh`:
   - Gắn nhãn `:rollback` cho image **đang chạy** — để có đường lùi
   - Kéo code mới, build image mới
   - *(chỉ backend)* Chạy migration database
   - Đổi sang container mới
   - **Health check**: gọi thật vào ứng dụng, tối đa 60 giây
4. **Không xanh trong 60 giây** → tự quay về image cũ, kiểm tra lại, và báo
   thất bại.
5. **Telegram** báo kết quả — kể cả khi hỏng ngay từ bước 1.

Vài điểm đáng nhớ:

- **Rollback dùng image cũ, không build lại từ nguồn.** Nhanh hơn nhiều và
  chắc chắn ra đúng thứ vừa chạy được.
- **Migration không bị hoàn tác.** Chúng chỉ thêm cột/bảng, không xoá, nên code
  cũ vẫn chạy được với schema mới. Đây là lý do migration phải viết theo kiểu
  "chỉ thêm".
- **Health check của API đòi `status: ok`**, không chấp nhận `degraded`. Nghĩa
  là API trả lời nhưng Postgres hoặc Redis chết thì vẫn tính là deploy hỏng —
  phục vụ người chơi một hệ thống què còn tệ hơn quay về bản cũ.
- **Hai lần push liên tiếp không giẫm lên nhau** — chúng xếp hàng.

---

## 5. Secret nằm ở đâu, mất thì sao

| Secret | Ở đâu | Mất thì sao |
|---|---|---|
| `ENCRYPTION_KEY` | `chuni-backend/.env` | **Nặng nhất.** Mọi người chơi phải liên kết lại tài khoản CHUNITHM-NET. Lộ ra thì người khác thao tác được trên CHUNITHM-NET dưới danh nghĩa họ, kể cả đổi tên tài khoản |
| `JWT_SECRET` | `chuni-backend/.env` | Mọi người bị đăng xuất. Đăng nhập lại là xong |
| `POSTGRES_PASSWORD` | `.env.prod` **và** trong `DATABASE_URL` | Hai chỗ phải khớp nhau. Lệch một ký tự là API không vào được database |
| SSH key | Máy bạn: `C:\Users\NovaSeele\.ssh\chunimai_deploy` | Mất thì không vào được server nữa — **hãy backup** |
| Token Telegram, GitHub Secrets | GitHub | Tạo lại được |

**Nên làm ngay nếu chưa:** copy `ENCRYPTION_KEY` ra một chỗ an toàn, **không**
để chung với file backup database. Có cả hai là có toàn bộ tài khoản người chơi;
có riêng một cái thì vô dụng.

Backup database chạy 02:15 giờ Việt Nam mỗi đêm, giữ 14 ngày, nằm trong
`chunimai-database/backups/` **trên chính VPS** — nên nó cứu được lỗi migration
hoặc xoá nhầm, **không** cứu được VPS chết. Thỉnh thoảng tải về máy.

---

## 6. Hỏng thì xem ở đâu

Theo thứ tự từ ngoài vào trong. Dừng ở bước đầu tiên cho kết quả bất thường.

| Triệu chứng | Xem gì |
|---|---|
| Trang không vào được | Cloudflare còn Proxied không, DNS còn trỏ đúng IP không |
| Lỗi 502 / 521 | nginx còn chạy không, container còn sống không (`docker ps`) |
| Trang lên nhưng trắng / thiếu dữ liệu | Log của API |
| Đăng nhập báo 429 | Bị chặn vì gọi quá nhiều — chờ 15 phút, hoặc xem mục 7 để chỉnh hạn mức |
| Deploy đỏ | Log GitHub Actions trước, log container sau |
| Chậm bất thường | `docker stats`, `free -h`, `df -h` |

Ba lệnh dùng nhiều nhất, sau khi SSH vào:

```bash
docker ps                                          # mọi thứ còn sống không
cd /home/repo/ChuniMaiWebApp/chuni-backend && docker compose logs -f api
curl -s localhost:3333/api/v1/health | jq          # API tự đánh giá mình
```

`/health` trả `ok` hoặc `degraded`, kèm trạng thái từng thành phần. Đây cũng là
thứ deploy dùng để quyết định thành công hay rollback — và cắm thẳng vào
UptimeRobot được nếu muốn cảnh báo tự động.

---

## 7. Những quyết định thiết kế và lý do

Phần này giải thích *vì sao* mọi thứ được làm như vậy. Đọc để sau này khỏi vô
tình phá.

**Vì sao `cloudflare-realip.conf` là file quan trọng bậc nhất.**
Sau Cloudflare, mọi request đến VPS đều mang IP của Cloudflare, không phải của
người dùng. Không có file này, bộ đếm số lần đăng nhập sai sẽ gộp **toàn bộ
người chơi vào chung một rổ**: vài lượt đăng nhập từ bất kỳ ai là người tiếp
theo bị khoá 15 phút — dù họ chưa gõ sai lần nào. Log truy cập cũng vô dụng
theo. Đã kiểm chứng bằng cách xem log ghi đúng IP thật.

**Vì sao API và giao diện ở hai domain khác nhau, nhưng cookie vẫn hoạt động.**
Cookie phiên được gắn cho `.novaseele.com` chứ không riêng domain API. Nếu chỉ
gắn cho domain API, trang render sẵn ở server sẽ luôn hiển thị trạng thái chưa
đăng nhập rồi mới nhảy sang đã-đăng-nhập khi trình duyệt chạy — nháy rất khó
chịu. Cách này cũng chuẩn bị sẵn cho các domain maimai sau này.

**Vì sao render ở server gọi API bằng địa chỉ nội bộ.**
Nếu dùng địa chỉ công khai, mỗi lần render một trang sẽ đi ra Cloudflare rồi
vòng ngược lại chính VPS đó — chậm, và biến CDN thành điểm hỏng cho việc hoàn
toàn nội bộ.

**Vì sao production không chạy Supabase đầy đủ.**
Máy local dựng 12 container. Backend nói chuyện thẳng với Postgres; thứ duy
nhất từng gọi Supabase là một dòng trạng thái. Production chỉ giữ Postgres,
Redis, và cặp cần cho Studio — 4 container. Khoảng 1 GB RAM tiết kiệm được cho
những dịch vụ không ai gọi.

**Vì sao `my-db` đang tắt.**
Studio bản self-host **không có đăng nhập**. Ai mở được trang là đọc/ghi được
mọi bảng, kể cả nơi chứa cookie jar đã mã hoá của mọi người chơi. Bật nó khi
chưa có Cloudflare Access còn nguy hiểm hơn lộ mật khẩu database. Ba lớp bảo vệ
đã chuẩn bị sẵn trong `nginx/my-db.conf`, chỉ cần bật Access rồi tạo symlink.

**Vì sao container chỉ mở cổng cho `127.0.0.1`.**
Docker mặc định mở ra `0.0.0.0` và **tự viết luật tường lửa riêng mà UFW không
thấy** — nghĩa là database sẽ nằm trần trên internet trong khi `ufw status` vẫn
báo "deny incoming". Đây là bẫy kinh điển. Khi thêm dịch vụ mới vào compose,
nhớ quy tắc này.

**Vì sao có `.gitattributes`.**
Windows lưu file xuống dòng kiểu khác Linux. Không ép, script deploy sẽ báo
`bad interpreter` trên server; tệ hơn, file cấu hình sẽ khiến mật khẩu bị dính
thêm một ký tự vô hình và không khớp nữa. Loại lỗi mất cả buổi để tìm.

**Vì sao có hai tầng hạn mức đăng nhập.**
nginx chặn ở tầng ngoài để dòng lũ không chạm tới ứng dụng; ứng dụng đếm trong
Redis theo cả IP lẫn tài khoản. Tầng nginx **phải luôn lỏng hơn** tầng ứng
dụng — nếu không, nginx sẽ từ chối trước khi ứng dụng kịp nói cho người dùng
biết *vì sao* họ bị chặn.

> Ghi chú: bạn đã nâng hạn mức lên 30/IP và 20/tài khoản mỗi 15 phút, nhưng
> phần chú thích trong `nginx/http-globals.conf` vẫn ghi con số cũ (20/10).
> Chỉ là chữ, không ảnh hưởng vận hành — nginx ở mức 40 lượt/phút vẫn lỏng hơn
> nhiều so với ứng dụng, đúng nguyên tắc. Sửa lại chú thích khi tiện tay.

---

## 8. Còn nợ

| Việc | Mức độ |
|---|---|
| Đổi mật khẩu root, tắt đăng nhập bằng mật khẩu | Nên làm sớm |
| Origin Certificate → chuyển **Full (Strict)** | Đang self-signed + Full: đã mã hoá, chưa xác thực |
| Bật `my-db` sau khi cấu hình Cloudflare Access | Khi cần xem database qua trình duyệt |
| Kiểm tra cookie khi đăng nhập thật lần đầu | Xem mục 9 của guide |
| Bật HSTS | Sau khi domain chạy ổn định vài tuần |

---

## 9. Tài liệu liên quan

| File | Nội dung |
|---|---|
| `SYSTEM_OVERVIEW.md` | File này — hiểu hệ thống |
| `PRODUCTION_DEPLOYMENT_GUIDE.md` | Lệnh cụ thể, dựng lại từ đầu, trạng thái hiện tại |
| `README.md` | Repo này chứa gì |
