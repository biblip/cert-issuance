#!/usr/bin/env bash
set -euo pipefail

CLIENT_NAME="${1:-}"

if [[ -z "$CLIENT_NAME" ]]; then
  echo "Usage: $0 <client-name>"
  exit 1
fi

sanitize_name() {
  printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_' | tr -s '_' '_'
}

SAFE_NAME="$(sanitize_name "$CLIENT_NAME")"
SAFE_NAME="${SAFE_NAME:-client}"

BASE_DIR="client/${SAFE_NAME}"
KEY="${BASE_DIR}/private/${SAFE_NAME}.key.pem"
CRT="${BASE_DIR}/cert/${SAFE_NAME}.crt.pem"

OUTDIR="trust-bundles/client/${SAFE_NAME}"

if [[ -d "trust-bundles" ]]; then
  echo "Warning: export target already exists (trust-bundles); delete it to re-export."
  exit 0
fi

[[ -f "$KEY" && -f "$CRT" ]] || { echo "Missing client key/cert ($KEY, $CRT)"; exit 1; }

mkdir -p "$OUTDIR"

cp -p "$KEY" "$OUTDIR/${SAFE_NAME}.key.pem"
cp -p "$CRT" "$OUTDIR/${SAFE_NAME}.crt.pem"

echo "Client bundle exported to: $OUTDIR"
