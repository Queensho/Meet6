#!/usr/bin/env bash
set -euo pipefail

umask 077

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 YYYYMMDDTHHMMSSZ [target-directory]" >&2
  exit 2
fi

STAMP="$1"
TARGET_DIR="${2:-/var/backups/meet6/recovered-$STAMP}"
OFFSITE_RCLONE_REMOTE="${OFFSITE_RCLONE_REMOTE:-}"
RCLONE_CONFIG="${RCLONE_CONFIG:-/etc/meet6/rclone.conf}"
VERIFY_BIN="${VERIFY_BIN:-/usr/local/sbin/meet6-backup-verify}"

[[ "$STAMP" =~ ^20[0-9]{6}T[0-9]{6}Z$ ]] || {
  echo "Invalid backup timestamp: $STAMP" >&2
  exit 2
}

[[ -n "$OFFSITE_RCLONE_REMOTE" ]] || {
  echo 'OFFSITE_RCLONE_REMOTE is not configured.' >&2
  exit 1
}

for command in rclone; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "Missing required command: $command" >&2
    exit 1
  }
done

[[ -f "$RCLONE_CONFIG" ]] || {
  echo "rclone config not found: $RCLONE_CONFIG" >&2
  exit 1
}
[[ -x "$VERIFY_BIN" ]] || {
  echo "Backup verifier not executable: $VERIFY_BIN" >&2
  exit 1
}
[[ ! -e "$TARGET_DIR" ]] || {
  echo "Target already exists: $TARGET_DIR" >&2
  exit 1
}

mkdir -p "$TARGET_DIR"
cleanup() {
  rm -rf "$TARGET_DIR"
}
trap cleanup EXIT

REMOTE_DIR="${OFFSITE_RCLONE_REMOTE%/}/$STAMP"
echo "[$(date -u +'%FT%TZ')] Fetching off-site backup $REMOTE_DIR"
rclone copy "$REMOTE_DIR" "$TARGET_DIR" \
  --config "$RCLONE_CONFIG" \
  --transfers 4 \
  --checkers 8 \
  --retries 4 \
  --low-level-retries 10

"$VERIFY_BIN" "$TARGET_DIR"
trap - EXIT

echo "Recovered and verified off-site backup: $TARGET_DIR"
