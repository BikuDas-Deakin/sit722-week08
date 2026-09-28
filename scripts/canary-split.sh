#!/usr/bin/env bash
# Usage: scripts/canary-split.sh [requests]
# Sends traffic, then asks Prometheus how many requests each service received.
set -euo pipefail
HOST="${HOST:-20.167.31.208.nip.io}"
N="${1:-200}"
echo "Sending $N requests to $HOST ..."
for i in $(seq 1 "$N"); do curl -s -o /dev/null "http://$HOST/"; done
echo "Waiting for Prometheus to scrape ..."
kubectl -n monitoring port-forward svc/prometheus-server 19090:80 >/dev/null 2>&1 &
PF=$!
trap 'kill $PF 2>/dev/null' EXIT
sleep 35
curl -s -G localhost:19090/api/v1/query --data-urlencode \
  'query=sum by (service) (increase(nginx_ingress_controller_requests{namespace="production"}[2m]))'
echo
