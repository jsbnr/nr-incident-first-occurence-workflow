#!/usr/bin/env bash
# Send a log message to New Relic via the Log API, repeating every 10 seconds until stopped (Ctrl-C).
# Usage: ./send_log.sh <INGEST_API_KEY> <MESSAGE>
# Set NR_LOG_ENDPOINT to override (e.g. https://log-api.eu.newrelic.com/log/v1 for EU).
# Set SEND_INTERVAL to change the seconds between sends (default 10).
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "Usage: $0 <INGEST_API_KEY> <MESSAGE>" >&2
  exit 1
fi

API_KEY="$1"
MESSAGE="$2"
ENDPOINT="${NR_LOG_ENDPOINT:-https://log-api.newrelic.com/log/v1}"
INTERVAL="${SEND_INTERVAL:-10}"

if command -v jq >/dev/null 2>&1; then
  BODY=$(jq -n --arg m "$MESSAGE" '{message: $m, service: "log-alert-test"}')
else
  ESCAPED=${MESSAGE//\\/\\\\}
  ESCAPED=${ESCAPED//\"/\\\"}
  BODY="{\"message\": \"$ESCAPED\", \"service\": \"log-alert-test\"}"
fi

trap 'echo; echo "Stopped."; exit 0' INT TERM

while true; do
  printf '%s ' "$(date +%T)"
  curl -sS -o /dev/null -w "HTTP %{http_code}\n" \
    -X POST "$ENDPOINT" \
    -H "Api-Key: $API_KEY" \
    -H "Content-Type: application/json" \
    -d "$BODY" || true
  sleep "$INTERVAL"
done
