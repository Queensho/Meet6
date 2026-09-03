#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Bu script root olarak çalıştırılmalı: sudo bash server/scripts/deploy-api-domain-production.sh" >&2
  exit 1
fi

REPO_ROOT="${MEET6_ROOT:-/var/www/meet6}"
API_DOMAIN="${MEET6_API_DOMAIN:-api.meet6.com.tr}"
NGINX_AVAILABLE="/etc/nginx/sites-available/meet6-api"
NGINX_ENABLED="/etc/nginx/sites-enabled/meet6-api"
APP_USER="${MEET6_APP_USER:-tayfun}"

if [[ ! -d "$REPO_ROOT/.git" ]]; then
  echo "Meet6 repo bulunamadı: $REPO_ROOT" >&2
  exit 1
fi

echo "[1/6] Repo güncelleniyor..."
git -C "$REPO_ROOT" pull --ff-only

echo "[2/6] API yerel sağlık kontrolü..."
curl -fsS http://127.0.0.1:3100/api/health >/dev/null

echo "[3/6] Nginx API sitesi kuruluyor..."
cp "$REPO_ROOT/server/ops/meet6-api.nginx" "$NGINX_AVAILABLE"
ln -sfn "$NGINX_AVAILABLE" "$NGINX_ENABLED"
nginx -t
systemctl reload nginx

# DNS'ten bağımsız Host-header smoke testi.
curl -fsS -H "Host: $API_DOMAIN" http://127.0.0.1/api/health >/dev/null

echo "[4/6] DNS kontrolü..."
PUBLIC_IP="$(curl -4fsS --max-time 5 https://api.ipify.org 2>/dev/null || true)"
DNS_IPS="$(getent ahostsv4 "$API_DOMAIN" 2>/dev/null | awk '{print $1}' | sort -u || true)"

if [[ -z "$PUBLIC_IP" ]] || ! grep -qx "$PUBLIC_IP" <<<"$DNS_IPS"; then
  echo
  echo "DNS henüz bu VPS'i göstermiyor. DNS panelinde şu kaydı ekle:"
  echo "  Tür: A"
  echo "  Host: api"
  echo "  Değer: ${PUBLIC_IP:-185.165.46.213}"
  echo "DNS yayıldıktan sonra bu scripti tekrar çalıştır."
  exit 2
fi

echo "[5/6] HTTPS kuruluyor/kontrol ediliyor..."
if ! command -v certbot >/dev/null 2>&1; then
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y certbot python3-certbot-nginx
fi

certbot --nginx \
  -d "$API_DOMAIN" \
  --non-interactive \
  --agree-tos \
  --register-unsafely-without-email \
  --redirect

nginx -t
systemctl reload nginx

echo "[6/6] Public smoke test..."
curl -fsS "https://$API_DOMAIN/api/health" >/dev/null

# Meet6 API'nin doğru PM2 kullanıcısında kayıtlı olduğunu da doğrula.
if id "$APP_USER" >/dev/null 2>&1; then
  sudo -u "$APP_USER" -H pm2 list || true
fi

echo
echo "Meet6 API production domain hazır: https://$API_DOMAIN"
echo "Health: https://$API_DOMAIN/api/health"
