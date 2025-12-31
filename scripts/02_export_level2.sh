#!/usr/bin/env bash
set -euo pipefail

OUTDIR="trust-bundles/level2"

ROOT_CRT="root/certs/root.crt.pem"
PARENT_CRT="level1/certs/level1.crt.pem"
LEVEL_KEY="level2/private/level2.key.pem"
LEVEL_CRT="level2/certs/level2.crt.pem"

mkdir -p "$OUTDIR"

[[ -f "$ROOT_CRT" ]] || { echo "Missing root cert ($ROOT_CRT)"; exit 1; }
[[ -f "$PARENT_CRT" ]] || { echo "Missing level1 cert ($PARENT_CRT)"; exit 1; }
[[ -f "$LEVEL_KEY" && -f "$LEVEL_CRT" ]] || { echo "Missing level2 key/cert ($LEVEL_KEY, $LEVEL_CRT)"; exit 1; }

cp -p "$LEVEL_KEY" "$OUTDIR/level2.key.pem"
cp -p "$LEVEL_CRT" "$OUTDIR/level2.crt.pem"

echo "Level 2 export created in: $OUTDIR"
