#!/usr/bin/env bash
set -euo pipefail

BUNDLE_DIR="${1:-trust-bundles}"

SRC_CRT="${BUNDLE_DIR}/level2/level2.crt.pem"
SRC_KEY="${BUNDLE_DIR}/level2/level2.key.pem"

ROOT_CRT="${BUNDLE_DIR}/root/root.crt.pem"
LEVEL1_CRT="${BUNDLE_DIR}/level1/level1.crt.pem"
LEVEL2_CRT="${BUNDLE_DIR}/level2/level2.crt.pem"
LEVEL3_CLIENT_CRT="${BUNDLE_DIR}/level3-client/level3-client.crt.pem"
LEVEL3_SERVER_CRT="${BUNDLE_DIR}/level3-server/level3-server.crt.pem"

DEST_CRT="level2/certs/level2.crt.pem"
DEST_KEY="level2/private/level2.key.pem"

[[ -f "$SRC_KEY" && -f "$SRC_CRT" ]] || { echo "Missing level2 bundle ($SRC_KEY, $SRC_CRT)"; exit 1; }

mkdir -p root/certs level1/certs level2/private level2/certs level3-client/certs level3-server/certs

[[ -e "$DEST_KEY" || -e "$DEST_CRT" ]] && { echo "Refusing to overwrite existing level2 key/cert ($DEST_KEY, $DEST_CRT)"; exit 1; }

cp -p "$SRC_KEY" "$DEST_KEY"
cp -p "$SRC_CRT" "$DEST_CRT"
chmod 600 "$DEST_KEY"

[[ -f "$ROOT_CRT" ]] && cp -p "$ROOT_CRT" "root/certs/root.crt.pem"
[[ -f "$LEVEL1_CRT" ]] && cp -p "$LEVEL1_CRT" "level1/certs/level1.crt.pem"
[[ -f "$LEVEL2_CRT" ]] && cp -p "$LEVEL2_CRT" "level2/certs/level2.crt.pem"
[[ -f "$LEVEL3_CLIENT_CRT" ]] && cp -p "$LEVEL3_CLIENT_CRT" "level3-client/certs/level3-client.crt.pem"
[[ -f "$LEVEL3_SERVER_CRT" ]] && cp -p "$LEVEL3_SERVER_CRT" "level3-server/certs/level3-server.crt.pem"

echo "Level 2 import complete:"
echo "  Key : $DEST_KEY"
echo "  Cert: $DEST_CRT"
