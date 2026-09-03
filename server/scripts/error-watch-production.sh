#!/usr/bin/env bash
set -euo pipefail

ERROR_LOG="${ERROR_LOG:-/var/log/meet6/api-error.log}"
STATE_DIR="${MEET6_OPS_STATE_DIR:-/var/lib/meet6-ops}"
STATE_FILE="$STATE_DIR/error-watch.state"
NOTIFY_BIN="${MEET6_NOTIFY_BIN:-/usr/local/sbin/meet6-notify}"

mkdir -p "$STATE_DIR"
[[ -f "$ERROR_LOG" ]] || exit 0

inode="$(stat -c '%i' "$ERROR_LOG")"
size="$(stat -c '%s' "$ERROR_LOG")"

if [[ ! -r "$STATE_FILE" ]]; then
  printf '%s %s\n' "$inode" "$size" > "$STATE_FILE"
  exit 0
fi

read -r previous_inode previous_size < "$STATE_FILE" || true
[[ "${previous_size:-}" =~ ^[0-9]+$ ]] || previous_size=0

if [[ "${previous_inode:-}" != "$inode" ]] || (( size < previous_size )); then
  previous_size=0
fi

if (( size == previous_size )); then
  exit 0
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

tail -c "+$((previous_size + 1))" "$ERROR_LOG" > "$tmp" || true
printf '%s %s\n' "$inode" "$size" > "$STATE_FILE"

count="$(grep -c '"level":"error"' "$tmp" || true)"
[[ "$count" =~ ^[0-9]+$ ]] || count=0
(( count > 0 )) || exit 0

last_event="$(grep '"level":"error"' "$tmp" | tail -n 1 | cut -c1-900 || true)"
message="Meet6 detected $count new application error event(s) in api-error.log"
if [[ -n "$last_event" ]]; then
  message="$message. Latest: $last_event"
fi

if [[ -x "$NOTIFY_BIN" ]]; then
  "$NOTIFY_BIN" "$message" || true
else
  logger -t meet6-error-watch -- "$message" 2>/dev/null || true
  echo "$message" >&2
fi
