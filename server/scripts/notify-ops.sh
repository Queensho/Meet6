#!/usr/bin/env bash
set -euo pipefail

MESSAGE="${*:-Meet6 production alert}"
WEBHOOK_URL="${OPS_ALERT_WEBHOOK_URL:-}"
WEBHOOK_FORMAT="${OPS_ALERT_WEBHOOK_FORMAT:-generic}"

logger -t meet6-ops -- "$MESSAGE" 2>/dev/null || true
printf '[%s] %s\n' "$(date -u +'%FT%TZ')" "$MESSAGE" >&2

[[ -n "$WEBHOOK_URL" ]] || exit 0
command -v curl >/dev/null 2>&1 || exit 0

escape_json() {
  printf '%s' "$1" \
    | sed 's/\\/\\\\/g; s/"/\\"/g' \
    | tr '\n' ' '
}

ESCAPED="$(escape_json "$MESSAGE")"
case "$WEBHOOK_FORMAT" in
  slack)
    PAYLOAD="{\"text\":\"$ESCAPED\"}"
    ;;
  discord)
    PAYLOAD="{\"content\":\"$ESCAPED\"}"
    ;;
  *)
    PAYLOAD="{\"message\":\"$ESCAPED\"}"
    ;;
esac

curl --fail --silent --show-error \
  --max-time 10 \
  -H 'Content-Type: application/json' \
  --data "$PAYLOAD" \
  "$WEBHOOK_URL" >/dev/null || true
