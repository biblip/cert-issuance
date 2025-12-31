#!/usr/bin/env bash
set -euo pipefail

EXTFILE="conf/ca_ext.cnf"

ISSUER_KEY="level3-server/private/level3-server.key.pem"
ISSUER_CRT="level3-server/certs/level3-server.crt.pem"

[[ -f "$ISSUER_KEY" && -f "$ISSUER_CRT" ]] || { echo "Missing level3 server key/cert ($ISSUER_KEY, $ISSUER_CRT)"; exit 1; }
[[ -f "$EXTFILE" ]] || { echo "Missing extension file: $EXTFILE"; exit 1; }

conf_get() {
  awk -F' *= *' -v section="defaults" -v key="$1" '
    $0 ~ "^\\[" section "\\]" { in_section=1; next }
    $0 ~ "^\\[" { in_section=0 }
    in_section && $1 == key { print $2; exit }
  ' "$EXTFILE"
}

SERVER_CN="${1:-$(conf_get server_cn)}"
SERVER_SAN="${2:-$(conf_get server_san)}"
DAYS="${3:-$(conf_get server_days)}"
KEY_BITS="${4:-$(conf_get server_key_bits)}"

SERVER_CN="${SERVER_CN:-server-001}"
SERVER_SAN="${SERVER_SAN:-DNS:server-001}"
DAYS="${DAYS:-825}"
KEY_BITS="${KEY_BITS:-3072}"

sanitize_name() {
  printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_' | tr -s '_' '_'
}

SAFE_CN="$(sanitize_name "$SERVER_CN")"
SAFE_CN="${SAFE_CN:-server}"

BASE_DIR="output/server/${SAFE_CN}"
KEY="${BASE_DIR}/private/${SAFE_CN}.key.pem"
CSR="${BASE_DIR}/reqs/${SAFE_CN}.csr.pem"
CRT="${BASE_DIR}/cert/${SAFE_CN}.crt.pem"

mkdir -p "${BASE_DIR}/private" "${BASE_DIR}/reqs" "${BASE_DIR}/cert"

[[ -e "$KEY" || -e "$CRT" ]] && { echo "Refusing to overwrite existing server key/cert ($KEY, $CRT)"; exit 1; }

openssl genrsa -out "$KEY" "$KEY_BITS"
chmod 600 "$KEY"

openssl req -new -sha256 \
  -key "$KEY" \
  -subj "/CN=${SERVER_CN}" \
  -out "$CSR"

TMP_EXT="$(mktemp)"
trap 'rm -f "$TMP_EXT"' EXIT

awk -v san="$SERVER_SAN" '
  /^\[ v3_server \]/ { print; in_section=1; next }
  in_section && /^\[/ {
    if (!added && san != "") { print "subjectAltName = " san; added=1 }
    in_section=0
  }
  { print }
  END {
    if (in_section && !added && san != "") { print "subjectAltName = " san }
  }
' "$EXTFILE" > "$TMP_EXT"

openssl x509 -req -sha256 \
  -in "$CSR" \
  -CA "$ISSUER_CRT" -CAkey "$ISSUER_KEY" -CAcreateserial \
  -days "$DAYS" \
  -out "$CRT" \
  -extfile "$TMP_EXT" -extensions v3_server

echo "Server certificate created:"
echo "  Key : $KEY"
echo "  Cert: $CRT"
openssl x509 -in "$CRT" -noout -subject -issuer -dates
