#!/usr/bin/env bash
set -euo pipefail

OUTDIR="trust-bundles/level1"

ROOT_CRT="root/certs/root.crt.pem"
LEVEL_KEY="level1/private/level1.key.pem"
LEVEL_CRT="level1/certs/level1.crt.pem"

mkdir -p "$OUTDIR"

[[ -f "$ROOT_CRT" ]] || { echo "Missing root cert ($ROOT_CRT)"; exit 1; }
[[ -f "$LEVEL_KEY" && -f "$LEVEL_CRT" ]] || { echo "Missing level1 key/cert ($LEVEL_KEY, $LEVEL_CRT)"; exit 1; }

cp -p "$LEVEL_KEY" "$OUTDIR/level1.key.pem"
cp -p "$LEVEL_CRT" "$OUTDIR/level1.crt.pem"

echo "Level 1 export created in: $OUTDIR"
