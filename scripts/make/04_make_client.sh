#!/usr/bin/env bash
set -euo pipefail

EXTFILE="conf/ca_ext.cnf"

ISSUER_KEY="level3-client/private/level3-client.key.pem"
ISSUER_CRT="level3-client/certs/level3-client.crt.pem"

[[ -f "$ISSUER_KEY" && -f "$ISSUER_CRT" ]] || { echo "Missing level3 client key/cert ($ISSUER_KEY, $ISSUER_CRT)"; exit 1; }
[[ -f "$EXTFILE" ]] || { echo "Missing extension file: $EXTFILE"; exit 1; }

conf_get() {
  awk -F' *= *' -v section="defaults" -v key="$1" '
    $0 ~ "^\\[" section "\\]" { in_section=1; next }
    $0 ~ "^\\[" { in_section=0 }
    in_section && $1 == key { print $2; exit }
  ' "$EXTFILE"
}

CLIENT_CN="${1:-$(conf_get client_cn)}"
DAYS="${2:-$(conf_get client_days)}"
KEY_BITS="${3:-$(conf_get client_key_bits)}"

CLIENT_CN="${CLIENT_CN:-client-001}"
DAYS="${DAYS:-825}"
KEY_BITS="${KEY_BITS:-3072}"

sanitize_name() {
  printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_' | tr -s '_' '_'
}

SAFE_CN="$(sanitize_name "$CLIENT_CN")"
SAFE_CN="${SAFE_CN:-client}"

BASE_DIR="output/client/${SAFE_CN}"
KEY="${BASE_DIR}/private/${SAFE_CN}.key.pem"
CSR="${BASE_DIR}/reqs/${SAFE_CN}.csr.pem"
CRT="${BASE_DIR}/cert/${SAFE_CN}.crt.pem"

mkdir -p "${BASE_DIR}/private" "${BASE_DIR}/reqs" "${BASE_DIR}/cert"

[[ -e "$KEY" || -e "$CRT" ]] && { echo "Refusing to overwrite existing client key/cert ($KEY, $CRT)"; exit 1; }

openssl genrsa -out "$KEY" "$KEY_BITS"
chmod 600 "$KEY"

openssl req -new -sha256 \
  -key "$KEY" \
  -subj "/CN=${CLIENT_CN}" \
  -out "$CSR"

openssl x509 -req -sha256 \
  -in "$CSR" \
  -CA "$ISSUER_CRT" -CAkey "$ISSUER_KEY" -CAcreateserial \
  -days "$DAYS" \
  -out "$CRT" \
  -extfile "$EXTFILE" -extensions v3_client

echo "Client certificate created:"
echo "  Key : $KEY"
echo "  Cert: $CRT"
openssl x509 -in "$CRT" -noout -subject -issuer -dates
