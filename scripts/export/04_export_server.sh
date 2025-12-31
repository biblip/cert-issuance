#!/usr/bin/env bash
set -euo pipefail

SERVER_NAME="${1:-}"
ALIAS_ARG="${2:-}"
PASSWORD_ARG="${3:-}"

if [[ -z "$SERVER_NAME" ]]; then
  echo "Usage: $0 <server-name> [alias] [password]"
  exit 1
fi

sanitize_name() {
  printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_' | tr -s '_' '_'
}

SAFE_NAME="$(sanitize_name "$SERVER_NAME")"
SAFE_NAME="${SAFE_NAME:-server}"

ALIAS="${ALIAS_ARG:-$SAFE_NAME}"
PASSWORD="${PASSWORD_ARG:-${P12_PASSWORD:-}}"

if [[ -z "$PASSWORD" ]]; then
  echo "Missing password. Provide it as an argument or set P12_PASSWORD."
  exit 1
fi

BASE_DIR="output/server/${SAFE_NAME}"
KEY="${BASE_DIR}/private/${SAFE_NAME}.key.pem"
CRT="${BASE_DIR}/cert/${SAFE_NAME}.crt.pem"

OUTDIR="trust-bundles/server/${SAFE_NAME}"
OUTP12="${OUTDIR}/${SAFE_NAME}.p12"

if [[ -d "trust-bundles" ]]; then
  echo "Warning: export target already exists (trust-bundles); delete it to re-export."
  exit 0
fi

[[ -f "$KEY" && -f "$CRT" ]] || { echo "Missing server key/cert ($KEY, $CRT)"; exit 1; }

mkdir -p "$OUTDIR"

CHAIN_TMP="$(mktemp)"
trap 'rm -f "$CHAIN_TMP"' EXIT

cat /dev/null > "$CHAIN_TMP"
[[ -f "level3-server/certs/level3-server.crt.pem" ]] && cat "level3-server/certs/level3-server.crt.pem" >> "$CHAIN_TMP"
[[ -f "level2/certs/level2.crt.pem" ]] && cat "level2/certs/level2.crt.pem" >> "$CHAIN_TMP"
[[ -f "level1/certs/level1.crt.pem" ]] && cat "level1/certs/level1.crt.pem" >> "$CHAIN_TMP"
[[ -f "root/certs/root.crt.pem" ]] && cat "root/certs/root.crt.pem" >> "$CHAIN_TMP"

if [[ -s "$CHAIN_TMP" ]]; then
  openssl pkcs12 -export \
    -name "$ALIAS" \
    -inkey "$KEY" \
    -in "$CRT" \
    -certfile "$CHAIN_TMP" \
    -out "$OUTP12" \
    -passout pass:"$PASSWORD"
else
  openssl pkcs12 -export \
    -name "$ALIAS" \
    -inkey "$KEY" \
    -in "$CRT" \
    -out "$OUTP12" \
    -passout pass:"$PASSWORD"
fi

echo "Server bundle exported to: $OUTP12"
