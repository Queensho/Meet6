#!/usr/bin/env bash
set -euo pipefail

umask 077

BACKUP_ROOT="${BACKUP_ROOT:-/var/backups/meet6}"
DB_NAME="${DB_NAME:-meet6}"
DB_USER="${DB_USER:-postgres}"
UPLOAD_ROOT="${UPLOAD_ROOT:-/var/www/meet6/uploads}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-14}"
LOCK_FILE="${LOCK_FILE:-/var/lock/meet6-backup.lock}"

for command in pg_dump pg_restore tar sha256sum flock; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "Missing required command: $command" >&2
    exit 1
  }
done

mkdir -p "$BACKUP_ROOT"
mkdir -p "$(dirname "$LOCK_FILE")"

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "Another Meet6 backup is already running" >&2
  exit 1
fi

STAMP="$(date -u +'%Y%m%dT%H%M%SZ')"
FINAL_DIR="$BACKUP_ROOT/$STAMP"
STAGING_DIR="$BACKUP_ROOT/.staging-$STAMP-$$"

cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

mkdir -p "$STAGING_DIR"

echo "[$(date -u +'%FT%TZ')] Backing up PostgreSQL database $DB_NAME"
if [[ "$(id -u)" -eq 0 ]] && command -v runuser >/dev/null 2>&1; then
  runuser -u "$DB_USER" -- pg_dump --format=custom --compress=9 --no-owner --no-acl "$DB_NAME" > "$STAGING_DIR/database.dump"
else
  pg_dump --username "$DB_USER" --format=custom --compress=9 --no-owner --no-acl "$DB_NAME" > "$STAGING_DIR/database.dump"
fi

pg_restore --list "$STAGING_DIR/database.dump" >/dev/null

echo "[$(date -u +'%FT%TZ')] Backing up uploaded profile media"
if [[ -d "$UPLOAD_ROOT" ]]; then
  tar -C "$UPLOAD_ROOT" -czf "$STAGING_DIR/uploads.tar.gz" .
else
  mkdir -p "$STAGING_DIR/empty-uploads"
  tar -C "$STAGING_DIR/empty-uploads" -czf "$STAGING_DIR/uploads.tar.gz" .
  rmdir "$STAGING_DIR/empty-uploads"
fi

tar -tzf "$STAGING_DIR/uploads.tar.gz" >/dev/null

cat > "$STAGING_DIR/metadata.txt" <<EOF
created_at_utc=$STAMP
database=$DB_NAME
upload_root=$UPLOAD_ROOT
hostname=$(hostname)
retention_days=$BACKUP_RETENTION_DAYS
EOF

(
  cd "$STAGING_DIR"
  sha256sum database.dump uploads.tar.gz metadata.txt > SHA256SUMS
  sha256sum -c SHA256SUMS
)

mv "$STAGING_DIR" "$FINAL_DIR"
trap - EXIT

# Remove abandoned staging directories older than one day and completed backups
# older than the configured retention period.
find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -name '.staging-*' -mtime +1 -exec rm -rf -- {} +
find "$BACKUP_ROOT" \
  -mindepth 1 \
  -maxdepth 1 \
  -type d \
  -name '20??????T??????Z' \
  -mtime "+$BACKUP_RETENTION_DAYS" \
  -print \
  -exec rm -rf -- {} +

echo "[$(date -u +'%FT%TZ')] Backup complete: $FINAL_DIR"
