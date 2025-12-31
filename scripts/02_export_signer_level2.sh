#!/usr/bin/env bash
set -euo pipefail

OUTDIR="trust-bundles"

ROOT_CRT="root/certs/root.crt.pem"
LEVEL1_CRT="level1/certs/level1.crt.pem"
LEVEL2_KEY="level2/private/level2.key.pem"
LEVEL2_CRT="level2/certs/level2.crt.pem"

if [[ -d "$OUTDIR" ]]; then
  echo "Warning: export target already exists (${OUTDIR}); delete it to re-export."
  exit 0
fi

[[ -f "$ROOT_CRT" ]] || { echo "Missing root cert ($ROOT_CRT)"; exit 1; }
[[ -f "$LEVEL1_CRT" ]] || { echo "Missing level1 cert ($LEVEL1_CRT)"; exit 1; }
[[ -f "$LEVEL2_KEY" && -f "$LEVEL2_CRT" ]] || { echo "Missing level2 key/cert ($LEVEL2_KEY, $LEVEL2_CRT)"; exit 1; }

mkdir -p "$OUTDIR/root" "$OUTDIR/level1" "$OUTDIR/level2"

cp -p "$ROOT_CRT" "$OUTDIR/root/root.crt.pem"
cp -p "$LEVEL1_CRT" "$OUTDIR/level1/level1.crt.pem"
cp -p "$LEVEL2_KEY" "$OUTDIR/level2/level2.key.pem"
cp -p "$LEVEL2_CRT" "$OUTDIR/level2/level2.crt.pem"

echo "Signer export created in: $OUTDIR"
