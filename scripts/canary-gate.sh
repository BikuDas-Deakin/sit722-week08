#!/usr/bin/env bash
# Canary gate: send real traffic, then judge the canary's 5xx rate from Prometheus.
# Usage: HOST=<ingress-host> scripts/canary-gate.sh [requests]
# Exit 0 = healthy (promote), exit 1 = unhealthy (roll back).
set -uo pipefail

HOST="${HOST:?set HOST, e.g. HOST=20.167.31.208.nip.io}"
N="${1:-600}"
THRESHOLD="${THRESHOLD:-5}"          # max allowed canary 5xx rate (%)
MIN_REQUESTS="${MIN_REQUESTS:-20}"   # canary must serve at least this many requests
CANARY="${CANARY_LABEL-production-frontend-canary-80}"
PORT="${PROM_PORT:-19090}"
PROM="http://localhost:${PORT}"
SUMMARY="${SUMMARY_FILE:-/tmp/canary-gate-summary.txt}"

kubectl -n monitoring port-forward svc/prometheus-server "${PORT}:80" >/dev/null 2>&1 &
PF=$!
trap 'kill $PF 2>/dev/null' EXIT
for i in $(seq 1 30); do curl -sf "$PROM/-/ready" >/dev/null && break; sleep 1; done

prom() {
  curl -s -G "$PROM/api/v1/query" --data-urlencode "query=$1" |
    python3 -c 'import sys,json; r=json.load(sys.stdin)["data"]["result"]; print(r[0]["value"][1] if r else 0)'
}
TOTAL_Q="sum(nginx_ingress_controller_requests{namespace=\"production\",canary=\"$CANARY\"})"
ERROR_Q="sum(nginx_ingress_controller_requests{namespace=\"production\",canary=\"$CANARY\",status=~\"5..\"})"

T0=$(prom "$TOTAL_Q"); E0=$(prom "$ERROR_Q")

echo "Sending $N requests to http://$HOST/ ..."
CODES=$(seq 1 "$N" | xargs -P 10 -I{} curl -s -o /dev/null -w '%{http_code}\n' "http://$HOST/")
CLIENT_FAILED=$(echo "$CODES" | grep -vc '^2')

echo "Waiting for Prometheus to scrape ..."
sleep 25
T1=$(prom "$TOTAL_Q"); E1=$(prom "$ERROR_Q")

CAN=$(awk -v a="$T1" -v b="$T0" 'BEGIN{printf "%d", a-b}')
ERR=$(awk -v a="$E1" -v b="$E0" 'BEGIN{printf "%d", a-b}')
RATE=$(awk -v e="$ERR" -v c="$CAN" 'BEGIN{ if (c>0) printf "%.1f", 100*e/c; else print "0.0" }')

MSG="canary_requests=$CAN canary_5xx=$ERR error_rate=${RATE}% threshold=${THRESHOLD}% client_failed=${CLIENT_FAILED}/${N}"
echo "GATE: $MSG"
echo "$MSG" > "$SUMMARY"

if [ "$CAN" -lt "$MIN_REQUESTS" ]; then
  echo "GATE RESULT: FAIL (canary got only $CAN requests, need $MIN_REQUESTS)"
  exit 1
fi
if awk -v r="$RATE" -v t="$THRESHOLD" 'BEGIN{exit !(r>t)}'; then
  echo "GATE RESULT: FAIL (error rate ${RATE}% is above ${THRESHOLD}%)"
  exit 1
fi
echo "GATE RESULT: PASS"
exit 0
