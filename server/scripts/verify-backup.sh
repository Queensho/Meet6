#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /var/backups/meet6/YYYYMMDDTHHMMSSZ" >&2
  exit 2
fi

BACKUP_DIR="${1%/}"

for command in pg_restore tar sha256sum; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "Missing required command: $command" >&2
    exit 1
  }
done

for file in database.dump uploads.tar.gz metadata.txt SHA256SUMS; do
  [[ -s "$BACKUP_DIR/$file" ]] || {
    echo "Missing or empty backup file: $BACKUP_DIR/$file" >&2
    exit 1
  }
done

(
  cd "$BACKUP_DIR"
  sha256sum -c SHA256SUMS
)

pg_restore --list "$BACKUP_DIR/database.dump" >/dev/null
tar -tzf "$BACKUP_DIR/uploads.tar.gz" >/dev/null

echo "Backup verified successfully: $BACKUP_DIR"
