#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run this installer as root (sudo)." >&2
  exit 1
fi

REPO_ROOT="${REPO_ROOT:-/var/www/meet6}"
SERVER_ROOT="$REPO_ROOT/server"

install -m 0755 "$SERVER_ROOT/scripts/backup-production.sh" /usr/local/sbin/meet6-backup
install -m 0755 "$SERVER_ROOT/scripts/verify-backup.sh" /usr/local/sbin/meet6-backup-verify
install -m 0644 "$SERVER_ROOT/ops/meet6-backup.service" /etc/systemd/system/meet6-backup.service
install -m 0644 "$SERVER_ROOT/ops/meet6-backup.timer" /etc/systemd/system/meet6-backup.timer

mkdir -p /var/backups/meet6
chmod 0700 /var/backups/meet6

systemctl daemon-reload
systemctl enable --now meet6-backup.timer

# Run one backup immediately so the installation is verified now, not tomorrow.
systemctl start meet6-backup.service
systemctl --no-pager --full status meet6-backup.timer || true
systemctl --no-pager --full status meet6-backup.service || true

echo "Meet6 daily backup timer installed and initial backup completed."
