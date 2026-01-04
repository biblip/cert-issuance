#!/usr/bin/env bash
set -euo pipefail

DIR="${1:-}"
NAME_ARG="${2:-}"
ALIAS_ARG="${3:-}"
PASSWORD_ARG="${4:-}"

if [[ -z "$DIR" ]]; then
  echo "Usage: $0 <bundle-dir> [name] [alias] [password]"
  exit 1
fi

if [[ ! -d "$DIR" ]]; then
  echo "Missing bundle directory: $DIR"
  exit 1
fi

base_name="$(basename "$DIR")"
NAME="${NAME_ARG:-$base_name}"
ALIAS="${ALIAS_ARG:-$NAME}"
PASSWORD="${PASSWORD_ARG:-${P12_PASSWORD:-}}"

if [[ -z "$PASSWORD" ]]; then
  echo "Missing password. Provide it as an argument or set P12_PASSWORD."
  exit 1
fi

KEY="${DIR}/${NAME}.key"
CRT="${DIR}/${NAME}.crt.pem"
P7B="${DIR}/${NAME}.p7b"
OUTP12="${DIR}/${NAME}.p12"

if [[ ! -f "$KEY" || ! -f "$CRT" ]]; then
  echo "Missing key or cert ($KEY, $CRT)"
  exit 1
fi

if [[ -f "$P7B" ]]; then
  TMP_CHAIN="$(mktemp)"
  trap 'rm -f "$TMP_CHAIN"' EXIT
  openssl pkcs7 -print_certs -in "$P7B" -out "$TMP_CHAIN"
  openssl pkcs12 -export \
    -name "$ALIAS" \
    -inkey "$KEY" \
    -in "$CRT" \
    -certfile "$TMP_CHAIN" \
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

echo "PKCS#12 bundle created: $OUTP12"
