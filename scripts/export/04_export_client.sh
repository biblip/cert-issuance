#!/usr/bin/env bash
set -euo pipefail

CLIENT_NAME="${1:-}"
ALIAS_ARG="${2:-}"
PASSWORD_ARG="${3:-}"

if [[ -z "$CLIENT_NAME" ]]; then
  echo "Usage: $0 <client-name> [alias] [password]"
  exit 1
fi

sanitize_name() {
  printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_' | tr -s '_' '_'
}

SAFE_NAME="$(sanitize_name "$CLIENT_NAME")"
SAFE_NAME="${SAFE_NAME:-client}"

ALIAS="${ALIAS_ARG:-$SAFE_NAME}"
PASSWORD="${PASSWORD_ARG:-${P12_PASSWORD:-}}"

BASE_DIR="output/client/${SAFE_NAME}"
KEY="${BASE_DIR}/private/${SAFE_NAME}.key.pem"
CRT="${BASE_DIR}/cert/${SAFE_NAME}.crt.pem"

OUTDIR="trust-bundles/client/${SAFE_NAME}"
OUTP12="${OUTDIR}/${SAFE_NAME}.p12"
OUT_P7B="${OUTDIR}/${SAFE_NAME}.p7b"

if [[ -d "trust-bundles" ]]; then
  echo "Warning: export target already exists (trust-bundles); delete it to re-export."
  exit 0
fi

if [[ ! -f "$CRT" ]]; then
  echo "Missing client cert ($CRT)"
  exit 1
fi

mkdir -p "$OUTDIR"

CHAIN_TMP="$(mktemp)"
trap 'rm -f "$CHAIN_TMP"' EXIT

cat /dev/null > "$CHAIN_TMP"
[[ -f "level3-client/certs/level3-client.crt.pem" ]] && cat "level3-client/certs/level3-client.crt.pem" >> "$CHAIN_TMP"
[[ -f "level2/certs/level2.crt.pem" ]] && cat "level2/certs/level2.crt.pem" >> "$CHAIN_TMP"
[[ -f "level1/certs/level1.crt.pem" ]] && cat "level1/certs/level1.crt.pem" >> "$CHAIN_TMP"
[[ -f "root/certs/root.crt.pem" ]] && cat "root/certs/root.crt.pem" >> "$CHAIN_TMP"

if [[ -f "$KEY" ]]; then
  if [[ -z "$PASSWORD" ]]; then
    echo "Missing password. Provide it as an argument or set P12_PASSWORD."
    exit 1
  fi
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
  echo "Client bundle exported to: $OUTP12"
else
  if [[ -s "$CHAIN_TMP" ]]; then
    cat "$CRT" "$CHAIN_TMP" | openssl crl2pkcs7 -nocrl -certfile /dev/stdin -out "$OUT_P7B"
  else
    openssl crl2pkcs7 -nocrl -certfile "$CRT" -out "$OUT_P7B"
  fi
  echo "Client certificate chain exported to: $OUT_P7B"
fi
