#!/usr/bin/env bash
# =============================================================================
# One-time provisioning for a fresh Ubuntu VPS (22.04 / 24.04).
#
#   chmod +x scripts/vps-setup.sh && ./scripts/vps-setup.sh
#
# Run as a normal user with sudo, not as root: the docker group membership is
# tied to whoever runs this, and root's copy is not the one the deploy uses.
#
# Idempotent — safe to re-run.
# =============================================================================

set -euo pipefail

log() { printf '\n\033[1;36m▸ %s\033[0m\n' "$*"; }

if [ "$(id -u)" -eq 0 ]; then
  echo "Run this as a sudo-capable user, not as root." >&2
  echo "The docker group membership is granted to the invoking user." >&2
  exit 1
fi

# -----------------------------------------------------------------------------
log "[1/8] System packages"
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y \
  ca-certificates curl gnupg git unzip build-essential \
  ufw nginx fail2ban logrotate jq

# -----------------------------------------------------------------------------
# Nuxt's build is the peak memory moment of a deploy and it happens on this box.
# On a 1–2 GB droplet it gets OOM-killed without swap, and the failure looks
# like a mysterious "Killed" with no stack trace.
log "[2/8] Swap file"
if swapon --show | grep -q '/swapfile'; then
  echo "swapfile already present, skipping"
else
  TOTAL_MB=$(free -m | awk '/^Mem:/ {print $2}')
  SWAP_GB=2
  [ "$TOTAL_MB" -ge 4000 ] && SWAP_GB=1
  sudo fallocate -l "${SWAP_GB}G" /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
  echo "vm.swappiness=10" | sudo tee /etc/sysctl.d/99-swappiness.conf
  sudo sysctl -p /etc/sysctl.d/99-swappiness.conf
  echo "Created ${SWAP_GB}G swap"
fi

# -----------------------------------------------------------------------------
log "[3/8] Node.js 22 (for the repo tooling; the apps run in containers)"
if ! command -v node >/dev/null || [ "$(node -v | cut -c2-3)" -lt 22 ]; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi
node -v

# -----------------------------------------------------------------------------
log "[4/8] Docker Engine and Compose plugin"
if ! command -v docker >/dev/null; then
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
sudo usermod -aG docker "$USER" || true
sudo systemctl enable --now docker

# One shared bridge for all three compose projects. Declared `external` in each
# compose file, so it has to exist before any of them come up.
sudo docker network inspect chunimai >/dev/null 2>&1 || sudo docker network create chunimai

# -----------------------------------------------------------------------------
log "[5/8] Firewall"
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
sudo ufw status verbose

# Docker writes its own iptables rules ahead of UFW's, so a container that
# publishes to 0.0.0.0 is reachable from the internet while `ufw status` still
# says deny. docker-compose.prod.yml binds both services to 127.0.0.1 for that
# reason — worth knowing before adding a service to it.
echo "Note: containers must publish to 127.0.0.1, not 0.0.0.0 — UFW does not filter Docker's rules."

# -----------------------------------------------------------------------------
log "[6/8] SSH brute-force protection"
sudo systemctl enable --now fail2ban

# -----------------------------------------------------------------------------
log "[7/8] Directories and Cloudflare origin-pull CA"
sudo mkdir -p /etc/ssl/cloudflare
sudo chmod 700 /etc/ssl/cloudflare
sudo mkdir -p /etc/nginx/snippets

# Needed by the my-db vhost: nginx demands a client certificate signed by this
# CA, which is what stops anyone reaching Studio by talking to the IP directly
# and skipping Cloudflare Access.
sudo curl -fsSL -o /etc/ssl/cloudflare/origin-pull-ca.pem   https://developers.cloudflare.com/ssl/static/authenticated_origin_pull_ca.pem   || echo "  (could not fetch the origin-pull CA — fetch it before enabling my-db)"

# Container logs are capped in each compose file (json-file, 10m x 5), so
# nothing here grows without bound.

# -----------------------------------------------------------------------------
log "[8/8] Docker on boot"
# Containers carry `restart: unless-stopped`, so the whole stack comes back on
# reboot as long as the daemon itself does.
sudo systemctl enable docker

cat <<'EOF'

──────────────────────────────────────────────────────────────────────
✅ VPS provisioned.

Next, in order — all paths relative to /home/repo/ChuniMaiWebApp:

  1. Log out and back in (or run `newgrp docker`) so docker works without sudo.

  2. Cloudflare Origin certificate:
       sudo nano /etc/ssl/cloudflare/origin.pem
       sudo nano /etc/ssl/cloudflare/origin.key
       sudo chmod 600 /etc/ssl/cloudflare/origin.key

  3. nginx — three vhosts:
       cd chunimai-database
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

  4. Environment files:
       cp chunimai-database/.env.prod.example chunimai-database/.env.prod
       cp chuni-backend/.env.production.example chuni-backend/.env
       # then fill in POSTGRES_PASSWORD, DATABASE_URL, ENCRYPTION_KEY, JWT_SECRET

  5. Data services, then the two apps:
       cd chunimai-database && ./scripts/deploy.sh && cd ..
       cd chuni-backend  && ./scripts/deploy.sh && cd ..
       cd chuni-frontend && ./scripts/deploy.sh && cd ..

  6. First song catalogue load (about 7,800 charts):
       cd chuni-backend
       docker compose run --rm migrate npm run seed:refresh
       docker compose run --rm migrate npm run seed:regions
──────────────────────────────────────────────────────────────────────
EOF
