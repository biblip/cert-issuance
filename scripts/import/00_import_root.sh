#!/usr/bin/env bash
set -euo pipefail

BUNDLE_DIR="${1:-trust-bundles/root}"

SRC_CRT="${BUNDLE_DIR}/root.crt.pem"
DEST_DIR="root/certs"
DEST_CRT="${DEST_DIR}/root.crt.pem"

[[ -f "$SRC_CRT" ]] || { echo "Missing root cert bundle: $SRC_CRT"; exit 1; }

mkdir -p "$DEST_DIR"

[[ -e "$DEST_CRT" ]] && { echo "Refusing to overwrite existing root cert ($DEST_CRT)"; exit 1; }

cp -p "$SRC_CRT" "$DEST_CRT"

echo "Root certificate imported to: $DEST_CRT"
