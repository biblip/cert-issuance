#!/usr/bin/env bash
set -euo pipefail

BUNDLE_DIR="${1:-trust-bundles}"

SRC_CRT="${BUNDLE_DIR}/level3/level3.crt.pem"
SRC_KEY="${BUNDLE_DIR}/level3/level3.key.pem"

ROOT_CRT="${BUNDLE_DIR}/root/root.crt.pem"
LEVEL1_CRT="${BUNDLE_DIR}/level1/level1.crt.pem"
LEVEL2_CRT="${BUNDLE_DIR}/level2/level2.crt.pem"
LEVEL3_CRT="${BUNDLE_DIR}/level3/level3.crt.pem"

DEST_CRT="level3/certs/level3.crt.pem"
DEST_KEY="level3/private/level3.key.pem"

[[ -f "$SRC_KEY" && -f "$SRC_CRT" ]] || { echo "Missing level3 bundle ($SRC_KEY, $SRC_CRT)"; exit 1; }

mkdir -p root/certs level1/certs level2/certs level3/private level3/certs

[[ -e "$DEST_KEY" || -e "$DEST_CRT" ]] && { echo "Refusing to overwrite existing level3 key/cert ($DEST_KEY, $DEST_CRT)"; exit 1; }

cp -p "$SRC_KEY" "$DEST_KEY"
cp -p "$SRC_CRT" "$DEST_CRT"
chmod 600 "$DEST_KEY"

[[ -f "$ROOT_CRT" ]] && cp -p "$ROOT_CRT" "root/certs/root.crt.pem"
[[ -f "$LEVEL1_CRT" ]] && cp -p "$LEVEL1_CRT" "level1/certs/level1.crt.pem"
[[ -f "$LEVEL2_CRT" ]] && cp -p "$LEVEL2_CRT" "level2/certs/level2.crt.pem"
[[ -f "$LEVEL3_CRT" ]] && cp -p "$LEVEL3_CRT" "level3/certs/level3.crt.pem"

echo "Level 3 import complete:"
echo "  Key : $DEST_KEY"
echo "  Cert: $DEST_CRT"
