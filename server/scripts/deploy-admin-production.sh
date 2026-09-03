#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Bu script root olarak çalıştırılmalı: sudo bash server/scripts/deploy-admin-production.sh +905XXXXXXXXX" >&2
  exit 1
fi

REPO_ROOT="${MEET6_ROOT:-/var/www/meet6}"
ADMIN_ROOT="${MEET6_ADMIN_ROOT:-/var/www/meet6-admin}"
ADMIN_DOMAIN="${MEET6_ADMIN_DOMAIN:-admin.meet6.com.tr}"
API_BASE_URL="${MEET6_API_BASE_URL:-https://api.meet6.com.tr}"
ADMIN_PHONE="${1:-${MEET6_ADMIN_PHONE:-}}"
ADMIN_ROLE="${MEET6_ADMIN_ROLE:-super_admin}"
NGINX_AVAILABLE="/etc/nginx/sites-available/meet6-admin"
NGINX_ENABLED="/etc/nginx/sites-enabled/meet6-admin"

if [[ ! -d "$REPO_ROOT/.git" ]]; then
  echo "Meet6 repo bulunamadı: $REPO_ROOT" >&2
  exit 1
fi

if [[ -n "$ADMIN_PHONE" && "$ADMIN_PHONE" != +* ]]; then
  echo "Admin telefonu E.164 biçiminde olmalı. Örnek: +905XXXXXXXXX" >&2
  exit 1
fi

case "$ADMIN_ROLE" in
  super_admin|moderator|support) ;;
  *) echo "Geçersiz admin rolü: $ADMIN_ROLE" >&2; exit 1 ;;
esac

echo "[1/8] Repo güncelleniyor..."
git -C "$REPO_ROOT" pull --ff-only

echo "[2/8] Backend bağımlılıkları, migration ve build..."
cd "$REPO_ROOT/server"
npm install
npm run migrate
npm run build

if [[ -n "$ADMIN_PHONE" ]]; then
  echo "[3/8] Admin yetkisi veriliyor: $ADMIN_ROLE"
  npm run admin:grant -- "$ADMIN_PHONE" "$ADMIN_ROLE"
else
  echo "[3/8] Admin telefonu verilmedi; yetkilendirme atlandı."
fi

echo "[4/8] API yeniden yükleniyor..."
if command -v pm2 >/dev/null 2>&1; then
  pm2 startOrReload ecosystem.config.cjs --env production
  pm2 save
else
  echo "PM2 bulunamadı. Önce production ops kurulumunu çalıştır." >&2
  exit 1
fi

echo "[5/8] Admin Flutter Web derleniyor..."
cd "$REPO_ROOT"
rm -rf build/web

build_admin() {
  flutter pub get
  flutter build web \
    --target lib/admin_main.dart \
    --release \
    --base-href / \
    --dart-define=MEET6_ENV=production \
    --dart-define="MEET6_API_BASE_URL=$API_BASE_URL"
}

if command -v flutter >/dev/null 2>&1; then
  build_admin
elif command -v docker >/dev/null 2>&1; then
  docker run --rm \
    -v "$REPO_ROOT:/workspace" \
    -w /workspace \
    ghcr.io/cirruslabs/flutter:stable \
    bash -lc "flutter pub get && flutter build web --target lib/admin_main.dart --release --base-href / --dart-define=MEET6_ENV=production --dart-define=MEET6_API_BASE_URL=$API_BASE_URL"
else
  echo "Flutter veya Docker bulunamadı. Admin web derlenemedi." >&2
  exit 1
fi

if [[ ! -f "$REPO_ROOT/build/web/index.html" ]]; then
  echo "Admin web build oluşmadı." >&2
  exit 1
fi

echo "[6/8] Admin statik dosyaları yayın dizinine alınıyor..."
mkdir -p "$ADMIN_ROOT"
if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete "$REPO_ROOT/build/web/" "$ADMIN_ROOT/"
else
  rm -rf "$ADMIN_ROOT"/*
  cp -a "$REPO_ROOT/build/web/." "$ADMIN_ROOT/"
fi
chown -R www-data:www-data "$ADMIN_ROOT" 2>/dev/null || true
find "$ADMIN_ROOT" -type d -exec chmod 755 {} +
find "$ADMIN_ROOT" -type f -exec chmod 644 {} +

echo "[7/8] Nginx admin sitesi kuruluyor..."
if ! command -v nginx >/dev/null 2>&1; then
  echo "Nginx bulunamadı." >&2
  exit 1
fi
cp "$REPO_ROOT/server/ops/meet6-admin.nginx" "$NGINX_AVAILABLE"
ln -sfn "$NGINX_AVAILABLE" "$NGINX_ENABLED"
nginx -t
systemctl reload nginx

# Host header ile DNS'ten bağımsız yerel smoke test.
curl -fsS -H "Host: $ADMIN_DOMAIN" http://127.0.0.1/ >/dev/null
curl -fsS http://127.0.0.1:3100/api/health >/dev/null

echo "[8/8] HTTPS kontrolü..."
PUBLIC_IP="$(curl -4fsS --max-time 5 https://api.ipify.org 2>/dev/null || true)"
DNS_IPS="$(getent ahostsv4 "$ADMIN_DOMAIN" 2>/dev/null | awk '{print $1}' | sort -u || true)"

if [[ -n "$PUBLIC_IP" ]] && grep -qx "$PUBLIC_IP" <<<"$DNS_IPS"; then
  if ! command -v certbot >/dev/null 2>&1; then
    if command -v apt-get >/dev/null 2>&1; then
      apt-get update
      DEBIAN_FRONTEND=noninteractive apt-get install -y certbot python3-certbot-nginx
    fi
  fi

  if command -v certbot >/dev/null 2>&1; then
    certbot --nginx \
      -d "$ADMIN_DOMAIN" \
      --non-interactive \
      --agree-tos \
      --register-unsafely-without-email \
      --redirect || true
    nginx -t && systemctl reload nginx
  fi
else
  echo
  echo "DNS henüz bu VPS'i göstermiyor. DNS panelinde şu kaydı ekle:"
  echo "  Tür: A"
  echo "  Host: admin"
  echo "  Değer: ${PUBLIC_IP:-VPS_PUBLIC_IP}"
  echo "DNS yayıldıktan sonra bu scripti tekrar çalıştır; HTTPS otomatik kurulacak."
fi

echo
pm2 list || true
echo "Admin yerel test: OK"
echo "Hedef adres: https://$ADMIN_DOMAIN"
if [[ -n "$ADMIN_PHONE" ]]; then
  echo "Admin hesabı: $ADMIN_PHONE ($ADMIN_ROLE)"
fi
