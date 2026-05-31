#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

patterns=(
  'PRIVATE KEY'
  'BEGIN OPENSSH PRIVATE KEY'
  'BEGIN RSA PRIVATE KEY'
  'BEGIN EC PRIVATE KEY'
  '74\.208\.22\.171'
  'deanluo'
  'telemetry\.dean\.jp'
  'us\.vpn\.dean\.jp'
)

for pattern in "${patterns[@]}"; do
  if grep -RInE "${pattern}" "${root}" \
    --exclude-dir=.git \
    --exclude='check-no-secrets.sh'; then
    echo "Potential secret or personal value found: ${pattern}" >&2
    exit 1
  fi
done

echo "No obvious secrets or personal infrastructure values found."
