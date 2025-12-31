#!/usr/bin/env bash
set -euo pipefail

OUTDIR="trust-bundles/level3"

ROOT_CRT="root/certs/root.crt.pem"
LEVEL1_CRT="level1/certs/level1.crt.pem"
LEVEL2_CRT="level2/certs/level2.crt.pem"
LEVEL_KEY="level3/private/level3.key.pem"
LEVEL_CRT="level3/certs/level3.crt.pem"

mkdir -p "$OUTDIR"

[[ -f "$ROOT_CRT" ]] || { echo "Missing root cert ($ROOT_CRT)"; exit 1; }
[[ -f "$LEVEL1_CRT" ]] || { echo "Missing level1 cert ($LEVEL1_CRT)"; exit 1; }
[[ -f "$LEVEL2_CRT" ]] || { echo "Missing level2 cert ($LEVEL2_CRT)"; exit 1; }
[[ -f "$LEVEL_KEY" && -f "$LEVEL_CRT" ]] || { echo "Missing level3 key/cert ($LEVEL_KEY, $LEVEL_CRT)"; exit 1; }

cp -p "$LEVEL_KEY" "$OUTDIR/level3.key.pem"
cp -p "$LEVEL_CRT" "$OUTDIR/level3.crt.pem"

echo "Level 3 export created in: $OUTDIR"
