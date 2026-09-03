#!/usr/bin/env bash
set -euo pipefail

umask 077

: "${DATABASE_URL:?DATABASE_URL is required}"

UPLOAD_ROOT="${UPLOAD_ROOT:-/var/www/meet6/uploads}"
BACKUP_ROOT="${BACKUP_ROOT:-/var/backups/meet6}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-14}"
MEET6_BACKUP_RCLONE_REMOTE="${MEET6_BACKUP_RCLONE_REMOTE:-}"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_DIR="${BACKUP_ROOT}/${STAMP}"
DB_FILE="${RUN_DIR}/postgres.dump"
UPLOAD_FILE="${RUN_DIR}/uploads.tar.gz"
MANIFEST_FILE="${RUN_DIR}/SHA256SUMS"

mkdir -p "${RUN_DIR}"
chmod 700 "${BACKUP_ROOT}" "${RUN_DIR}"

cleanup_failed_run() {
  if [[ "${1:-0}" != "0" ]]; then
    rm -rf "${RUN_DIR}"
  fi
}
trap 'status=$?; cleanup_failed_run "$status"; exit "$status"' EXIT

echo "[meet6-backup] PostgreSQL dump started: ${STAMP}"
pg_dump \
  --format=custom \
  --compress=9 \
  --no-owner \
  --no-privileges \
  --file="${DB_FILE}" \
  "${DATABASE_URL}"

# Validate that pg_restore can read the archive before considering it a backup.
pg_restore --list "${DB_FILE}" >/dev/null

if [[ -d "${UPLOAD_ROOT}" ]]; then
  echo "[meet6-backup] Archiving uploads from ${UPLOAD_ROOT}"
  upload_parent="$(dirname "${UPLOAD_ROOT}")"
  upload_name="$(basename "${UPLOAD_ROOT}")"
  tar -C "${upload_parent}" -czf "${UPLOAD_FILE}" "${upload_name}"
  tar -tzf "${UPLOAD_FILE}" >/dev/null
else
  echo "[meet6-backup] Upload directory missing; writing empty archive"
  tmp_empty="$(mktemp -d)"
  tar -C "${tmp_empty}" -czf "${UPLOAD_FILE}" .
  rm -rf "${tmp_empty}"
fi

(
  cd "${RUN_DIR}"
  sha256sum postgres.dump uploads.tar.gz > "$(basename "${MANIFEST_FILE}")"
  sha256sum --check "$(basename "${MANIFEST_FILE}")"
)

ln -sfn "${RUN_DIR}" "${BACKUP_ROOT}/latest"

# Delete completed local backup directories older than the retention window.
find "${BACKUP_ROOT}" \
  -mindepth 1 \
  -maxdepth 1 \
  -type d \
  -mtime "+${BACKUP_RETENTION_DAYS}" \
  -print \
  -exec rm -rf {} +

if [[ -n "${MEET6_BACKUP_RCLONE_REMOTE}" ]]; then
  if ! command -v rclone >/dev/null 2>&1; then
    echo "[meet6-backup] ERROR: MEET6_BACKUP_RCLONE_REMOTE is set but rclone is not installed" >&2
    exit 1
  fi

  remote="${MEET6_BACKUP_RCLONE_REMOTE%/}/${STAMP}"
  echo "[meet6-backup] Copying encrypted/private backup data off-site to ${remote}"
  rclone copy "${RUN_DIR}" "${remote}" --checksum --retries 3
fi

echo "[meet6-backup] Backup verified successfully: ${RUN_DIR}"
trap - EXIT
