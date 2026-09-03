#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run with sudo: sudo bash /var/www/meet6/ops/backup/install.sh" >&2
  exit 1
fi

REPO_ROOT="/var/www/meet6"
BACKUP_ROOT="${BACKUP_ROOT:-/var/backups/meet6}"

command -v pg_dump >/dev/null 2>&1 || {
  apt-get update
  apt-get install -y postgresql-client
}

install -d -m 700 "${BACKUP_ROOT}"
chmod 700 "${REPO_ROOT}/ops/backup/meet6-backup.sh"
install -m 644 "${REPO_ROOT}/ops/backup/meet6-backup.service" /etc/systemd/system/meet6-backup.service
install -m 644 "${REPO_ROOT}/ops/backup/meet6-backup.timer" /etc/systemd/system/meet6-backup.timer

systemctl daemon-reload
systemctl enable --now meet6-backup.timer

# Run one backup immediately. The installer only succeeds if PostgreSQL dump,
# upload archive and checksum verification all complete successfully.
systemctl start meet6-backup.service
systemctl --no-pager --full status meet6-backup.service || true
systemctl --no-pager list-timers meet6-backup.timer

latest="$(readlink -f "${BACKUP_ROOT}/latest" 2>/dev/null || true)"
if [[ -z "${latest}" || ! -f "${latest}/postgres.dump" || ! -f "${latest}/SHA256SUMS" ]]; then
  echo "Meet6 backup verification failed: latest backup is incomplete" >&2
  exit 1
fi

(
  cd "${latest}"
  sha256sum --check SHA256SUMS
  pg_restore --list postgres.dump >/dev/null
)

echo "Meet6 nightly backup is installed and verified: ${latest}"
