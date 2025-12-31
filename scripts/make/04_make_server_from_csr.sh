#!/usr/bin/env bash
set -euo pipefail

SERVER_NAME="${1:-}"
CSR_PATH="${2:-}"
SAN_ARG="${3:-}"
DAYS_ARG="${4:-}"

EXTFILE="conf/ca_ext.cnf"
ISSUER_KEY="level3-server/private/level3-server.key.pem"
ISSUER_CRT="level3-server/certs/level3-server.crt.pem"

if [[ -z "$SERVER_NAME" || -z "$CSR_PATH" ]]; then
  echo "Usage: $0 <server-name> <csr-path> [san] [days]"
  exit 1
fi

if [[ ! -f "$CSR_PATH" ]]; then
  echo "Missing CSR file: $CSR_PATH"
  exit 1
fi

[[ -f "$ISSUER_KEY" && -f "$ISSUER_CRT" ]] || { echo "Missing level3 server key/cert ($ISSUER_KEY, $ISSUER_CRT)"; exit 1; }
[[ -f "$EXTFILE" ]] || { echo "Missing extension file: $EXTFILE"; exit 1; }

conf_get() {
  awk -F' *= *' -v section="defaults" -v key="$1" '
    $0 ~ "^\\[" section "\\]" { in_section=1; next }
    $0 ~ "^\\[" { in_section=0 }
    in_section && $1 == key { print $2; exit }
  ' "$EXTFILE"
}

SERVER_SAN="${SAN_ARG:-$(conf_get server_san)}"
DAYS="${DAYS_ARG:-$(conf_get server_days)}"

SERVER_SAN="${SERVER_SAN:-DNS:server-001}"
DAYS="${DAYS:-825}"

sanitize_name() {
  printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_' | tr -s '_' '_'
}

SAFE_NAME="$(sanitize_name "$SERVER_NAME")"
SAFE_NAME="${SAFE_NAME:-server}"

BASE_DIR="output/server/${SAFE_NAME}"
CSR="${BASE_DIR}/reqs/${SAFE_NAME}.csr.pem"
CRT="${BASE_DIR}/cert/${SAFE_NAME}.crt.pem"

mkdir -p "${BASE_DIR}/private" "${BASE_DIR}/reqs" "${BASE_DIR}/cert"

[[ -e "$CRT" ]] && { echo "Refusing to overwrite existing server cert ($CRT)"; exit 1; }

cp -p "$CSR_PATH" "$CSR"

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

echo "Server certificate created from CSR:"
echo "  CSR : $CSR"
echo "  Cert: $CRT"
openssl x509 -in "$CRT" -noout -subject -issuer -dates
