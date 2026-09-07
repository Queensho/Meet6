#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Bu script root olarak çalıştırılmalı: sudo bash server/scripts/deploy-api-domain-production.sh" >&2
  exit 1
fi

REPO_ROOT="${MEET6_ROOT:-/var/www/meet6}"
SERVER_ROOT="$REPO_ROOT/server"
API_DOMAIN="${MEET6_API_DOMAIN:-api.meet6.com.tr}"
NGINX_AVAILABLE="/etc/nginx/sites-available/meet6-api"
NGINX_ENABLED="/etc/nginx/sites-enabled/meet6-api"
APP_USER="${MEET6_APP_USER:-tayfun}"
APP_HOME="$(getent passwd "$APP_USER" | cut -d: -f6)"
[[ -n "$APP_HOME" ]] || APP_HOME="/home/$APP_USER"

if [[ ! -d "$REPO_ROOT/.git" ]]; then
  echo "Meet6 repo bulunamadı: $REPO_ROOT" >&2
  exit 1
fi
if [[ ! -f "$SERVER_ROOT/package.json" ]]; then
  echo "Meet6 server bulunamadı: $SERVER_ROOT" >&2
  exit 1
fi
if ! id "$APP_USER" >/dev/null 2>&1; then
  echo "Uygulama kullanıcısı bulunamadı: $APP_USER" >&2
  exit 1
fi

run_as_app() {
  runuser -u "$APP_USER" -- env HOME="$APP_HOME" PATH="$PATH" "$@"
}

wait_for_health() {
  local url="$1"
  for _ in $(seq 1 30); do
    if curl -fsS --max-time 3 "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

echo "[1/8] Repo güncelleniyor..."
git -C "$REPO_ROOT" pull --ff-only

echo "[2/8] Backend bağımlılıkları kuruluyor..."
run_as_app bash -lc "cd '$SERVER_ROOT' && npm ci"

echo "[3/8] Backend derleniyor..."
run_as_app bash -lc "cd '$SERVER_ROOT' && npm run build"

echo "[4/8] Veritabanı migrationları uygulanıyor..."
run_as_app bash -lc "cd '$SERVER_ROOT' && npm run migrate"

echo "[5/8] PM2 production API yeniden yükleniyor..."
PM2_BIN="$(command -v pm2 || true)"
if [[ -z "$PM2_BIN" ]]; then
  echo "pm2 bulunamadı." >&2
  exit 1
fi
run_as_app "$PM2_BIN" startOrReload "$SERVER_ROOT/ecosystem.config.cjs" --env production
run_as_app "$PM2_BIN" save

if ! wait_for_health "http://127.0.0.1:3100/api/health"; then
  echo "Yeni backend başladı ancak yerel health kontrolünü geçemedi." >&2
  run_as_app "$PM2_BIN" logs meet6-api --lines 80 --nostream || true
  exit 1
fi

echo "[6/8] Nginx API sitesi doğrulanıyor..."
cp "$SERVER_ROOT/ops/meet6-api.nginx" "$NGINX_AVAILABLE"
ln -sfn "$NGINX_AVAILABLE" "$NGINX_ENABLED"
nginx -t
systemctl reload nginx
curl -fsS -H "Host: $API_DOMAIN" http://127.0.0.1/api/health >/dev/null

echo "[7/8] DNS / HTTPS kontrolü..."
PUBLIC_IP="$(curl -4fsS --max-time 5 https://api.ipify.org 2>/dev/null || true)"
DNS_IPS="$(getent ahostsv4 "$API_DOMAIN" 2>/dev/null | awk '{print $1}' | sort -u || true)"
if [[ -z "$PUBLIC_IP" ]] || ! grep -qx "$PUBLIC_IP" <<<"$DNS_IPS"; then
  echo "DNS bu VPS'i göstermiyor. Beklenen IP: ${PUBLIC_IP:-185.165.46.213}" >&2
  exit 2
fi
if ! command -v certbot >/dev/null 2>&1; then
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y certbot python3-certbot-nginx
fi
certbot --nginx -d "$API_DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email --redirect
nginx -t
systemctl reload nginx

echo "[8/8] Public smoke testleri..."
wait_for_health "https://$API_DOMAIN/api/health"

ROUTE_STATUS="$(curl -sS -o /dev/null -w '%{http_code}' -X POST \
  -H 'Content-Type: application/json' \
  -d '{"gameKey":"red_flag_green_flag"}' \
  "https://$API_DOMAIN/api/rooms/game/0/force-finish" || true)"
if [[ "$ROUTE_STATUS" == "404" || "$ROUTE_STATUS" == "000" ]]; then
  echo "force-finish route production'da aktif değil. HTTP $ROUTE_STATUS" >&2
  exit 1
fi

run_as_app "$PM2_BIN" list || true

echo
echo "Meet6 API production deploy tamamlandı."
echo "Health: https://$API_DOMAIN/api/health"
echo "force-finish route status (auth'suz smoke): HTTP $ROUTE_STATUS"
