#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Bu script root olarak çalıştırılmalı: sudo bash server/scripts/deploy-admin-production.sh +905XXXXXXXXX" >&2
  exit 1
fi

REPO_ROOT="${MEET6_ROOT:-/var/www/meet6}"
ADMIN_ROOT="${MEET6_ADMIN_ROOT:-/var/www/meet6-admin}"
ADMIN_DOMAIN="${MEET6_ADMIN_DOMAIN:-admin.meet6.com.tr}"
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

APP_USER="${MEET6_APP_USER:-${SUDO_USER:-}}"
if [[ -z "$APP_USER" || "$APP_USER" == root ]]; then
  APP_USER="$(stat -c '%U' "$REPO_ROOT")"
fi
if [[ -z "$APP_USER" || "$APP_USER" == root ]]; then
  echo "Meet6 uygulama kullanıcısı belirlenemedi. MEET6_APP_USER=tayfun ile tekrar çalıştır." >&2
  exit 1
fi
APP_GROUP="$(id -gn "$APP_USER")"
APP_HOME="$(getent passwd "$APP_USER" | cut -d: -f6)"
if [[ -z "$APP_HOME" ]]; then
  echo "Uygulama kullanıcısının HOME dizini bulunamadı: $APP_USER" >&2
  exit 1
fi

run_as_app() {
  runuser -u "$APP_USER" -- env HOME="$APP_HOME" bash -lc "$*"
}

# Önceki hatalı root deployundan kalabilecek dosya sahipliğini düzelt.
chown -R "$APP_USER:$APP_GROUP" "$REPO_ROOT/.git" 2>/dev/null || true
for path in "$REPO_ROOT/server/dist" "$REPO_ROOT/server/node_modules" "$REPO_ROOT/server/package-lock.json"; do
  [[ -e "$path" ]] && chown -R "$APP_USER:$APP_GROUP" "$path" 2>/dev/null || true
done

echo "[1/8] Repo güncelleniyor... (app user: $APP_USER)"
run_as_app "git -C '$REPO_ROOT' pull --ff-only"
TARGET_SHA="$(git -C "$REPO_ROOT" rev-parse HEAD)"

echo "[2/8] Backend bağımlılıkları, migration ve build..."
run_as_app "cd '$REPO_ROOT/server' && npm install && npm run migrate && npm run build"

if [[ -n "$ADMIN_PHONE" ]]; then
  echo "[3/8] Admin yetkisi veriliyor: $ADMIN_ROLE"
  run_as_app "cd '$REPO_ROOT/server' && npm run admin:grant -- '$ADMIN_PHONE' '$ADMIN_ROLE'"
else
  echo "[3/8] Admin telefonu verilmedi; yetkilendirme atlandı."
fi

echo "[4/8] API PM2 altında '$APP_USER' kullanıcısıyla yeniden yükleniyor..."
# İlk sürümde sudo ile yanlışlıkla açılmış root PM2 meet6-api sürecini temizle.
if command -v pm2 >/dev/null 2>&1; then
  PM2_HOME=/root/.pm2 pm2 delete meet6-api >/dev/null 2>&1 || true
  PM2_HOME=/root/.pm2 pm2 save --force >/dev/null 2>&1 || true
fi

if ! run_as_app "command -v pm2 >/dev/null 2>&1"; then
  echo "PM2 '$APP_USER' kullanıcısında bulunamadı. Production ops kurulumunu kontrol et." >&2
  exit 1
fi
run_as_app "cd '$REPO_ROOT/server' && pm2 startOrReload ecosystem.config.cjs --env production && pm2 save"

echo "[5/8] GitHub CI admin web paketi bekleniyor..."
# VPS'te Flutter/Docker gerekmez. GitHub Actions production admin build'ini
# admin-web dalına yayınlar. Aynı commitin paketi gelene kadar bekle.
ADMIN_BRANCH_READY=false
for attempt in $(seq 1 60); do
  run_as_app "git -C '$REPO_ROOT' fetch --force origin admin-web:refs/remotes/origin/admin-web" >/dev/null 2>&1 || true
  SOURCE_SHA="$(git -C "$REPO_ROOT" show origin/admin-web:.admin-source-sha 2>/dev/null | tr -d '\r\n' || true)"
  if [[ "$SOURCE_SHA" == "$TARGET_SHA" ]]; then
    ADMIN_BRANCH_READY=true
    break
  fi
  if (( attempt % 6 == 0 )); then
    echo "  CI bekleniyor... ${attempt}0 sn (hedef ${TARGET_SHA:0:7}, gelen ${SOURCE_SHA:0:7})"
  fi
  sleep 10
done

if [[ "$ADMIN_BRANCH_READY" != true ]]; then
  echo "GitHub CI admin-web paketi 10 dakika içinde hazır olmadı." >&2
  echo "Actions durumunu kontrol edip aynı deploy komutunu tekrar çalıştır." >&2
  exit 1
fi

echo "[6/8] Admin statik dosyaları yayın dizinine alınıyor..."
TMP_ADMIN="$(mktemp -d)"
trap 'rm -rf "$TMP_ADMIN"' EXIT
git -C "$REPO_ROOT" archive origin/admin-web | tar -x -C "$TMP_ADMIN"
if [[ ! -f "$TMP_ADMIN/index.html" ]]; then
  echo "admin-web dalında index.html bulunamadı." >&2
  exit 1
fi
mkdir -p "$ADMIN_ROOT"
if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete "$TMP_ADMIN/" "$ADMIN_ROOT/"
else
  find "$ADMIN_ROOT" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
  cp -a "$TMP_ADMIN/." "$ADMIN_ROOT/"
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
run_as_app "pm2 list" || true
echo "Admin yerel test: OK"
echo "Admin build SHA: $TARGET_SHA"
echo "Hedef adres: https://$ADMIN_DOMAIN"
if [[ -n "$ADMIN_PHONE" ]]; then
  echo "Admin hesabı: $ADMIN_PHONE ($ADMIN_ROLE)"
fi
