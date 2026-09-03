#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo 'Run this installer as root (sudo).' >&2
  exit 1
fi

REPO_ROOT="${REPO_ROOT:-/var/www/meet6}"
SERVER_ROOT="$REPO_ROOT/server"

[[ -d "$SERVER_ROOT" ]] || {
  echo "Meet6 server directory not found: $SERVER_ROOT" >&2
  exit 1
}

APP_USER="${APP_USER:-$(stat -c '%U' "$SERVER_ROOT")}"
id "$APP_USER" >/dev/null 2>&1 || {
  echo "APP_USER does not exist: $APP_USER" >&2
  exit 1
}
APP_GROUP="${APP_GROUP:-$(id -gn "$APP_USER")}"
APP_HOME="${APP_HOME:-$(getent passwd "$APP_USER" | cut -d: -f6)}"
[[ -n "$APP_HOME" ]] || APP_HOME="/root"

for command in install systemctl curl logrotate stat getent; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "Missing required command: $command" >&2
    exit 1
  }
done

install -m 0755 "$SERVER_ROOT/scripts/backup-production.sh" /usr/local/sbin/meet6-backup
install -m 0755 "$SERVER_ROOT/scripts/verify-backup.sh" /usr/local/sbin/meet6-backup-verify
install -m 0755 "$SERVER_ROOT/scripts/notify-ops.sh" /usr/local/sbin/meet6-notify
install -m 0755 "$SERVER_ROOT/scripts/healthcheck-production.sh" /usr/local/sbin/meet6-healthcheck
install -m 0755 "$SERVER_ROOT/scripts/error-watch-production.sh" /usr/local/sbin/meet6-error-watch

for unit in \
  meet6-backup.service \
  meet6-backup.timer \
  meet6-health.service \
  meet6-health.timer \
  meet6-error-watch.service \
  meet6-error-watch.timer \
  'meet6-ops-alert@.service'; do
  install -m 0644 "$SERVER_ROOT/ops/$unit" "/etc/systemd/system/$unit"
done

install -m 0644 "$SERVER_ROOT/ops/meet6-logrotate" /etc/logrotate.d/meet6

if [[ ! -f /etc/default/meet6-ops ]]; then
  install -m 0600 "$SERVER_ROOT/ops/meet6-ops.env.example" /etc/default/meet6-ops
fi

install -d -m 0700 /var/backups/meet6
install -d -m 0750 -o "$APP_USER" -g "$APP_GROUP" /var/log/meet6
install -d -m 0750 -o "$APP_USER" -g "$APP_GROUP" /var/lib/meet6-ops
touch /var/log/meet6/api-out.log /var/log/meet6/api-error.log
chown "$APP_USER:$APP_GROUP" /var/log/meet6/api-out.log /var/log/meet6/api-error.log
chmod 0640 /var/log/meet6/api-out.log /var/log/meet6/api-error.log

bash -n \
  "$SERVER_ROOT/scripts/backup-production.sh" \
  "$SERVER_ROOT/scripts/verify-backup.sh" \
  "$SERVER_ROOT/scripts/notify-ops.sh" \
  "$SERVER_ROOT/scripts/healthcheck-production.sh" \
  "$SERVER_ROOT/scripts/error-watch-production.sh"

logrotate --debug /etc/logrotate.d/meet6 >/dev/null 2>&1 || {
  echo 'Meet6 logrotate configuration is invalid.' >&2
  exit 1
}

systemctl daemon-reload
systemctl enable --now meet6-backup.timer
systemctl enable --now meet6-health.timer
systemctl enable --now meet6-error-watch.timer

PM2_BIN="$(command -v pm2 || true)"
if [[ -n "$PM2_BIN" ]]; then
  run_pm2() {
    if [[ "$APP_USER" == 'root' ]]; then
      env HOME="$APP_HOME" PATH="$PATH" "$PM2_BIN" "$@"
    else
      runuser -u "$APP_USER" -- env HOME="$APP_HOME" PATH="$PATH" "$PM2_BIN" "$@"
    fi
  }

  run_pm2 startOrReload "$SERVER_ROOT/ecosystem.config.cjs" --env production
  run_pm2 save

  # Creates/enables pm2-<user>.service so the saved process list is restored
  # after a VPS reboot.
  env PATH="$PATH" "$PM2_BIN" startup systemd -u "$APP_USER" --hp "$APP_HOME" >/dev/null
else
  echo 'WARNING: pm2 is not installed; install it globally, then rerun this script.' >&2
fi

# Validate the complete chain immediately.
systemctl start meet6-backup.service
/usr/local/sbin/meet6-backup-verify /var/backups/meet6/latest
systemctl start meet6-health.service || true

systemctl --no-pager --full status meet6-backup.timer || true
systemctl --no-pager --full status meet6-health.timer || true
systemctl --no-pager --full status meet6-error-watch.timer || true

echo
printf 'Meet6 production operations installed. App user: %s\n' "$APP_USER"
echo 'Configure optional alerts/heartbeat in /etc/default/meet6-ops.'
