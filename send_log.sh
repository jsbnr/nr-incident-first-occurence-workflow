#!/usr/bin/env bash
# Send a log message to New Relic via the Log API.
# Usage: ./send_log.sh <INGEST_API_KEY> <MESSAGE>
# Set NR_LOG_ENDPOINT to override (e.g. https://log-api.eu.newrelic.com/log/v1 for EU).
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "Usage: $0 <INGEST_API_KEY> <MESSAGE>" >&2
  exit 1
fi

API_KEY="$1"
MESSAGE="$2"
ENDPOINT="${NR_LOG_ENDPOINT:-https://log-api.newrelic.com/log/v1}"

if command -v jq >/dev/null 2>&1; then
  BODY=$(jq -n --arg m "$MESSAGE" '{message: $m, service: "piglet-test"}')
else
  ESCAPED=${MESSAGE//\\/\\\\}
  ESCAPED=${ESCAPED//\"/\\\"}
  BODY="{\"message\": \"$ESCAPED\", \"service\": \"piglet-test\"}"
fi

curl -sS -o /dev/null -w "HTTP %{http_code}\n" \
  -X POST "$ENDPOINT" \
  -H "Api-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d "$BODY"
