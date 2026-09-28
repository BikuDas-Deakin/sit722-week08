#!/usr/bin/env bash
# Continuous load generator for zero-downtime proof during canary promotion.
# Usage: HOST=<ingress-host> scripts/load.sh [requests_per_second]
# Runs until Ctrl+C. Prints a running total and non-2xx count every second.
set -uo pipefail

HOST="${HOST:?set HOST, e.g. HOST=20.167.31.208.nip.io}"
RPS="${1:-10}"

TOTAL=0
FAILED=0

trap 'echo; echo "FINAL: total=$TOTAL failed=$FAILED"; exit 0' INT TERM

echo "Sending ~${RPS} req/s to http://$HOST/ (Ctrl+C to stop) ..."

while true; do
  CODES=$(seq 1 "$RPS" | xargs -P "$RPS" -I{} curl -s -o /dev/null -w '%{http_code}\n' "http://$HOST/")
  BATCH=$(echo "$CODES" | wc -l | tr -d ' ')
  BATCH_FAILED=$(echo "$CODES" | grep -vc '^2')

  TOTAL=$((TOTAL + BATCH))
  FAILED=$((FAILED + BATCH_FAILED))

  echo "total=$TOTAL failed=$FAILED"
  sleep 1
done