#!/usr/bin/env bash
set -euo pipefail

HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:3100/api/health}"
HEALTH_TIMEOUT_SECONDS="${HEALTH_TIMEOUT_SECONDS:-8}"
HEALTH_FAILURE_THRESHOLD="${HEALTH_FAILURE_THRESHOLD:-3}"
UPTIME_HEARTBEAT_URL="${UPTIME_HEARTBEAT_URL:-}"
STATE_DIR="${MEET6_OPS_STATE_DIR:-/var/lib/meet6-ops}"
STATE_FILE="$STATE_DIR/health.failures"
NOTIFY_BIN="${MEET6_NOTIFY_BIN:-/usr/local/sbin/meet6-notify}"

command -v curl >/dev/null 2>&1 || {
  echo 'curl is required for Meet6 health monitoring' >&2
  exit 2
}

mkdir -p "$STATE_DIR"
failures=0
if [[ -r "$STATE_FILE" ]]; then
  read -r failures < "$STATE_FILE" || failures=0
fi
[[ "$failures" =~ ^[0-9]+$ ]] || failures=0

response=''
healthy=false
if response="$(curl --fail --silent --show-error --max-time "$HEALTH_TIMEOUT_SECONDS" "$HEALTH_URL" 2>/dev/null)"; then
  if grep -Eq '"ok"[[:space:]]*:[[:space:]]*true' <<<"$response" \
    && grep -Eq '"database"[[:space:]]*:[[:space:]]*"ok"' <<<"$response" \
    && grep -Eq '"redis"[[:space:]]*:[[:space:]]*"ok"' <<<"$response"; then
    healthy=true
  fi
fi

notify() {
  local message="$1"
  if [[ -x "$NOTIFY_BIN" ]]; then
    "$NOTIFY_BIN" "$message" || true
  else
    logger -t meet6-health -- "$message" 2>/dev/null || true
    echo "$message" >&2
  fi
}

if [[ "$healthy" == true ]]; then
  if (( failures >= HEALTH_FAILURE_THRESHOLD )); then
    notify "Meet6 API recovered after $failures failed health checks: $HEALTH_URL"
  fi
  printf '0\n' > "$STATE_FILE"

  if [[ -n "$UPTIME_HEARTBEAT_URL" ]]; then
    curl --fail --silent --show-error --max-time "$HEALTH_TIMEOUT_SECONDS" \
      "$UPTIME_HEARTBEAT_URL" >/dev/null || true
  fi

  echo "[$(date -u +'%FT%TZ')] Meet6 health OK"
  exit 0
fi

failures=$((failures + 1))
printf '%s\n' "$failures" > "$STATE_FILE"

echo "[$(date -u +'%FT%TZ')] Meet6 health FAILED ($failures/$HEALTH_FAILURE_THRESHOLD): $HEALTH_URL" >&2
if (( failures == HEALTH_FAILURE_THRESHOLD )); then
  notify "Meet6 API health check failed $failures consecutive times: $HEALTH_URL"
fi

exit 1
