#!/usr/bin/env bash
set -euo pipefail

EXTFILE="conf/ca_ext.cnf"

mkdir -p root/private root/certs
KEY="root/private/root.key.pem"
CRT="root/certs/root.crt.pem"

if [[ ! -f "$EXTFILE" ]]; then
  echo "Missing extension file: $EXTFILE"
  exit 1
fi

conf_get() {
  awk -F' *= *' -v section="defaults" -v key="$1" '
    $0 ~ "^\\[" section "\\]" { in_section=1; next }
    $0 ~ "^\\[" { in_section=0 }
    in_section && $1 == key { print $2; exit }
  ' "$EXTFILE"
}

CN="${1:-$(conf_get root_cn)}"
DAYS="${2:-$(conf_get root_days)}"
KEY_BITS="${3:-$(conf_get root_key_bits)}"

CN="${CN:-Root CA}"
DAYS="${DAYS:-9125}"
KEY_BITS="${KEY_BITS:-4096}"

if [[ -f "$KEY" || -f "$CRT" ]]; then
  echo "Refusing to overwrite existing root key/cert: $KEY or $CRT"
  exit 1
fi

openssl genrsa -out "$KEY" "$KEY_BITS"
chmod 600 "$KEY"

# IMPORTANT FIX:
# openssl req -x509 does NOT accept -extfile.
# Extensions must be provided through -config.
# We embed the shared extfile into an in-memory config and point x509_extensions to v3_root_ca.
openssl req -x509 -new \
  -key "$KEY" \
  -sha256 \
  -days "$DAYS" \
  -subj "/CN=${CN}" \
  -out "$CRT" \
  -config <(cat <<EOF
[ req ]
distinguished_name = dn
x509_extensions = v3_root_ca
prompt = no

[ dn ]
CN = ${CN}

$(cat "$EXTFILE")
EOF
)

echo "Root CA created:"
echo "  Key : $KEY"
echo "  Cert: $CRT"
openssl x509 -in "$CRT" -noout -subject -issuer -dates
