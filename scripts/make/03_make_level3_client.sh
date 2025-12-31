#!/usr/bin/env bash
set -euo pipefail

EXTFILE="conf/ca_ext.cnf"

IM_KEY="level2/private/level2.key.pem"
IM_CRT="level2/certs/level2.crt.pem"

mkdir -p level3-client/private level3-client/certs level3-client/reqs
KEY="level3-client/private/level3-client.key.pem"
CSR="level3-client/reqs/level3-client.csr.pem"
CRT="level3-client/certs/level3-client.crt.pem"

[[ -f "$IM_KEY" && -f "$IM_CRT" ]] || { echo "Missing level2 key/cert ($IM_KEY, $IM_CRT)"; exit 1; }
[[ -f "$EXTFILE" ]] || { echo "Missing extension file: $EXTFILE"; exit 1; }

conf_get() {
  awk -F' *= *' -v section="defaults" -v key="$1" '
    $0 ~ "^\\[" section "\\]" { in_section=1; next }
    $0 ~ "^\\[" { in_section=0 }
    in_section && $1 == key { print $2; exit }
  ' "$EXTFILE"
}

CN="${1:-$(conf_get level3_client_cn)}"
DAYS="${2:-$(conf_get level3_client_days)}"
KEY_BITS="${3:-$(conf_get level3_client_key_bits)}"

CN="${CN:-Level 3 Client CA}"
DAYS="${DAYS:-1825}"
KEY_BITS="${KEY_BITS:-4096}"

[[ -e "$KEY" || -e "$CRT" ]] && { echo "Refusing to overwrite existing level3 client key/cert ($KEY, $CRT)"; exit 1; }

openssl genrsa -out "$KEY" "$KEY_BITS"
chmod 600 "$KEY"

openssl req -new -sha256 \
  -key "$KEY" \
  -subj "/CN=${CN}" \
  -out "$CSR"

openssl x509 -req -sha256 \
  -in "$CSR" \
  -CA "$IM_CRT" -CAkey "$IM_KEY" -CAcreateserial \
  -days "$DAYS" \
  -out "$CRT" \
  -extfile "$EXTFILE" -extensions v3_level3_ca

echo "Level 3 Client CA created:"
echo "  Key : $KEY"
echo "  Cert: $CRT"
openssl x509 -in "$CRT" -noout -subject -issuer -dates
