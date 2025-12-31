#!/usr/bin/env bash
set -euo pipefail

EXTFILE="conf/ca_ext.cnf"

ROOT_KEY="root/private/root.key.pem"
ROOT_CRT="root/certs/root.crt.pem"

mkdir -p level1/private level1/certs level1/reqs
KEY="level1/private/level1.key.pem"
CSR="level1/reqs/level1.csr.pem"
CRT="level1/certs/level1.crt.pem"

[[ -f "$ROOT_KEY" && -f "$ROOT_CRT" ]] || { echo "Missing root key/cert ($ROOT_KEY, $ROOT_CRT)"; exit 1; }
[[ -f "$EXTFILE" ]] || { echo "Missing extension file: $EXTFILE"; exit 1; }

conf_get() {
  awk -F' *= *' -v section="defaults" -v key="$1" '
    $0 ~ "^\\[" section "\\]" { in_section=1; next }
    $0 ~ "^\\[" { in_section=0 }
    in_section && $1 == key { print $2; exit }
  ' "$EXTFILE"
}

CN="${1:-$(conf_get level1_cn)}"
DAYS="${2:-$(conf_get level1_days)}"
KEY_BITS="${3:-$(conf_get level1_key_bits)}"

CN="${CN:-Level 1 CA}"
DAYS="${DAYS:-5475}"
KEY_BITS="${KEY_BITS:-4096}"

[[ -e "$KEY" || -e "$CRT" ]] && { echo "Refusing to overwrite existing level1 key/cert ($KEY, $CRT)"; exit 1; }

openssl genrsa -out "$KEY" "$KEY_BITS"
chmod 600 "$KEY"

openssl req -new -sha256 \
  -key "$KEY" \
  -subj "/CN=${CN}" \
  -out "$CSR"

openssl x509 -req -sha256 \
  -in "$CSR" \
  -CA "$ROOT_CRT" -CAkey "$ROOT_KEY" -CAcreateserial \
  -days "$DAYS" \
  -out "$CRT" \
  -extfile "$EXTFILE" -extensions v3_level1_ca

echo "Level 1 CA created:"
echo "  Key : $KEY"
echo "  Cert: $CRT"
openssl x509 -in "$CRT" -noout -subject -issuer -dates
