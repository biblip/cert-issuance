#!/usr/bin/env bash
set -euo pipefail

EXTFILE="conf/ca_ext.cnf"

MASTER_KEY="level1/private/level1.key.pem"
MASTER_CRT="level1/certs/level1.crt.pem"

mkdir -p level2/private level2/certs level2/reqs
KEY="level2/private/level2.key.pem"
CSR="level2/reqs/level2.csr.pem"
CRT="level2/certs/level2.crt.pem"

[[ -f "$MASTER_KEY" && -f "$MASTER_CRT" ]] || { echo "Missing level1 key/cert ($MASTER_KEY, $MASTER_CRT)"; exit 1; }
[[ -f "$EXTFILE" ]] || { echo "Missing extension file: $EXTFILE"; exit 1; }

conf_get() {
  awk -F' *= *' -v section="defaults" -v key="$1" '
    $0 ~ "^\\[" section "\\]" { in_section=1; next }
    $0 ~ "^\\[" { in_section=0 }
    in_section && $1 == key { print $2; exit }
  ' "$EXTFILE"
}

CN="${1:-$(conf_get level2_cn)}"
DAYS="${2:-$(conf_get level2_days)}"
KEY_BITS="${3:-$(conf_get level2_key_bits)}"

CN="${CN:-Level 2 CA}"
DAYS="${DAYS:-3650}"
KEY_BITS="${KEY_BITS:-4096}"

[[ -e "$KEY" || -e "$CRT" ]] && { echo "Refusing to overwrite existing level2 key/cert ($KEY, $CRT)"; exit 1; }

openssl genrsa -out "$KEY" "$KEY_BITS"
chmod 600 "$KEY"

openssl req -new -sha256 \
  -key "$KEY" \
  -subj "/CN=${CN}" \
  -out "$CSR"

openssl x509 -req -sha256 \
  -in "$CSR" \
  -CA "$MASTER_CRT" -CAkey "$MASTER_KEY" -CAcreateserial \
  -days "$DAYS" \
  -out "$CRT" \
  -extfile "$EXTFILE" -extensions v3_level2_ca

echo "Level 2 CA created:"
echo "  Key : $KEY"
echo "  Cert: $CRT"
openssl x509 -in "$CRT" -noout -subject -issuer -dates
