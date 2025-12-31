#!/usr/bin/env bash
set -euo pipefail

BUNDLE_DIR="${1:-trust-bundles/level2}"

SRC_CRT="${BUNDLE_DIR}/level2.crt.pem"
SRC_KEY="${BUNDLE_DIR}/level2.key.pem"

DEST_CRT="level2/certs/level2.crt.pem"
DEST_KEY="level2/private/level2.key.pem"

[[ -f "$SRC_CRT" ]] || { echo "Missing level2 cert bundle ($SRC_CRT)"; exit 1; }

mkdir -p level2/private level2/certs

[[ -e "$DEST_KEY" || -e "$DEST_CRT" ]] && { echo "Refusing to overwrite existing level2 key/cert ($DEST_KEY, $DEST_CRT)"; exit 1; }

cp -p "$SRC_CRT" "$DEST_CRT"
if [[ -f "$SRC_KEY" ]]; then
  cp -p "$SRC_KEY" "$DEST_KEY"
  chmod 600 "$DEST_KEY"
else
  echo "Warning: level2 key not found in bundle; importing cert only."
fi

echo "Level 2 import complete:"
if [[ -f "$DEST_KEY" ]]; then
  echo "  Key : $DEST_KEY"
fi
echo "  Cert: $DEST_CRT"
