#!/usr/bin/env bash
set -euo pipefail

umask 077

BACKUP_ROOT="${BACKUP_ROOT:-/var/backups/meet6}"
SOURCE_DIR="${1:-$BACKUP_ROOT/latest}"
OFFSITE_RCLONE_REMOTE="${OFFSITE_RCLONE_REMOTE:-}"
OFFSITE_BACKUP_REQUIRED="${OFFSITE_BACKUP_REQUIRED:-false}"
RCLONE_CONFIG="${RCLONE_CONFIG:-/etc/meet6/rclone.conf}"
BACKUP_HEARTBEAT_URL="${BACKUP_HEARTBEAT_URL:-}"

required() {
  case "${1,,}" in
    1|true|yes|on) return 0 ;;
    *) return 1 ;;
  esac
}

if [[ -z "$OFFSITE_RCLONE_REMOTE" ]]; then
  if required "$OFFSITE_BACKUP_REQUIRED"; then
    echo 'OFFSITE_BACKUP_REQUIRED is enabled but OFFSITE_RCLONE_REMOTE is empty.' >&2
    exit 1
  fi
  echo 'Off-site backup is not configured; local verified backup remains available.' >&2
  exit 0
fi

for command in rclone readlink basename sha256sum curl; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "Missing required command: $command" >&2
    exit 1
  }
done

[[ -f "$RCLONE_CONFIG" ]] || {
  echo "rclone config not found: $RCLONE_CONFIG" >&2
  exit 1
}

REAL_SOURCE="$(readlink -f "$SOURCE_DIR")"
[[ -d "$REAL_SOURCE" ]] || {
  echo "Backup directory not found: $SOURCE_DIR" >&2
  exit 1
}

STAMP="$(basename "$REAL_SOURCE")"
[[ "$STAMP" =~ ^20[0-9]{6}T[0-9]{6}Z$ ]] || {
  echo "Unexpected backup directory name: $STAMP" >&2
  exit 1
}

for file in database.dump uploads.tar.gz metadata.txt SHA256SUMS; do
  [[ -s "$REAL_SOURCE/$file" ]] || {
    echo "Missing or empty backup file: $REAL_SOURCE/$file" >&2
    exit 1
  }
done

(
  cd "$REAL_SOURCE"
  sha256sum -c SHA256SUMS >/dev/null
)

REMOTE_ROOT="${OFFSITE_RCLONE_REMOTE%/}"
REMOTE_DIR="$REMOTE_ROOT/$STAMP"

echo "[$(date -u +'%FT%TZ')] Uploading verified backup $STAMP to off-site storage"
rclone copy "$REAL_SOURCE" "$REMOTE_DIR" \
  --config "$RCLONE_CONFIG" \
  --immutable \
  --transfers 4 \
  --checkers 8 \
  --retries 4 \
  --low-level-retries 10

# Verify that the remote contains the same files and byte sizes. When the remote
# is an rclone crypt remote, this check happens through the decrypted view.
rclone check "$REAL_SOURCE" "$REMOTE_DIR" \
  --config "$RCLONE_CONFIG" \
  --size-only \
  --one-way

MARKER="$(mktemp)"
trap 'rm -f "$MARKER"' EXIT
cat > "$MARKER" <<EOF
backup=$STAMP
verified_at_utc=$(date -u +'%FT%TZ')
source_host=$(hostname)
EOF
rclone copyto "$MARKER" "$REMOTE_ROOT/latest.txt" --config "$RCLONE_CONFIG"

if [[ -n "$BACKUP_HEARTBEAT_URL" ]]; then
  curl -fsS \
    --connect-timeout 5 \
    --max-time 15 \
    --retry 3 \
    --retry-delay 2 \
    "$BACKUP_HEARTBEAT_URL" >/dev/null
fi

echo "[$(date -u +'%FT%TZ')] Off-site backup verified: $REMOTE_DIR"
