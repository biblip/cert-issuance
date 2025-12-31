#!/usr/bin/env bash
set -euo pipefail

CLIENT_NAME="${1:-}"
CSR_PATH="${2:-}"
DAYS_ARG="${3:-}"

EXTFILE="conf/ca_ext.cnf"
ISSUER_KEY="level3/private/level3.key.pem"
ISSUER_CRT="level3/certs/level3.crt.pem"

if [[ -z "$CLIENT_NAME" || -z "$CSR_PATH" ]]; then
  echo "Usage: $0 <client-name> <csr-path> [days]"
  exit 1
fi

if [[ ! -f "$CSR_PATH" ]]; then
  echo "Missing CSR file: $CSR_PATH"
  exit 1
fi

[[ -f "$ISSUER_KEY" && -f "$ISSUER_CRT" ]] || { echo "Missing level3 key/cert ($ISSUER_KEY, $ISSUER_CRT)"; exit 1; }
[[ -f "$EXTFILE" ]] || { echo "Missing extension file: $EXTFILE"; exit 1; }

conf_get() {
  awk -F' *= *' -v section="defaults" -v key="$1" '
    $0 ~ "^\\[" section "\\]" { in_section=1; next }
    $0 ~ "^\\[" { in_section=0 }
    in_section && $1 == key { print $2; exit }
  ' "$EXTFILE"
}

DAYS="${DAYS_ARG:-$(conf_get client_days)}"
DAYS="${DAYS:-825}"

sanitize_name() {
  printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_' | tr -s '_' '_'
}

SAFE_NAME="$(sanitize_name "$CLIENT_NAME")"
SAFE_NAME="${SAFE_NAME:-client}"

BASE_DIR="client/${SAFE_NAME}"
CSR="${BASE_DIR}/reqs/${SAFE_NAME}.csr.pem"
CRT="${BASE_DIR}/cert/${SAFE_NAME}.crt.pem"

mkdir -p "${BASE_DIR}/private" "${BASE_DIR}/reqs" "${BASE_DIR}/cert"

[[ -e "$CRT" ]] && { echo "Refusing to overwrite existing client cert ($CRT)"; exit 1; }

cp -p "$CSR_PATH" "$CSR"

openssl x509 -req -sha256 \
  -in "$CSR" \
  -CA "$ISSUER_CRT" -CAkey "$ISSUER_KEY" -CAcreateserial \
  -days "$DAYS" \
  -out "$CRT" \
  -extfile "$EXTFILE" -extensions v3_client

echo "Client certificate created from CSR:"
echo "  CSR : $CSR"
echo "  Cert: $CRT"
openssl x509 -in "$CRT" -noout -subject -issuer -dates
