#!/usr/bin/env bash
# Usage: scripts/canary-weight.sh <0-100>
# Sets the percentage of traffic that the canary Ingress receives.
set -euo pipefail
W="${1:?usage: canary-weight.sh <0-100>}"
if ! [[ "$W" =~ ^[0-9]+$ ]] || [ "$W" -gt 100 ]; then
  echo "weight must be a number from 0 to 100"; exit 1
fi
kubectl annotate ingress frontend-canary -n production \
  nginx.ingress.kubernetes.io/canary-weight="$W" --overwrite
echo "canary weight is now ${W}%"
