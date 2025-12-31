#!/usr/bin/env bash
set -euo pipefail

BUNDLE_DIR="${1:-trust-bundles/level2}"

SRC_KEY="${BUNDLE_DIR}/level2.key.pem"
SRC_CRT="${BUNDLE_DIR}/level2.crt.pem"

DEST_KEY="level2/private/level2.key.pem"
DEST_CRT="level2/certs/level2.crt.pem"

[[ -f "$SRC_KEY" && -f "$SRC_CRT" ]] || { echo "Missing level2 bundle ($SRC_KEY, $SRC_CRT)"; exit 1; }

mkdir -p level2/private level2/certs

[[ -e "$DEST_KEY" || -e "$DEST_CRT" ]] && { echo "Refusing to overwrite existing level2 key/cert ($DEST_KEY, $DEST_CRT)"; exit 1; }

cp -p "$SRC_KEY" "$DEST_KEY"
cp -p "$SRC_CRT" "$DEST_CRT"
chmod 600 "$DEST_KEY"

echo "Level 2 key/cert imported:"
echo "  Key : $DEST_KEY"
echo "  Cert: $DEST_CRT"
