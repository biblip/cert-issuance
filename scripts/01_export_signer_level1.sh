#!/usr/bin/env bash
set -euo pipefail

OUTDIR="trust-bundles"

ROOT_CRT="root/certs/root.crt.pem"
LEVEL1_KEY="level1/private/level1.key.pem"
LEVEL1_CRT="level1/certs/level1.crt.pem"

if [[ -d "$OUTDIR" ]]; then
  echo "Warning: export target already exists (${OUTDIR}); delete it to re-export."
  exit 0
fi

[[ -f "$ROOT_CRT" ]] || { echo "Missing root cert ($ROOT_CRT)"; exit 1; }
[[ -f "$LEVEL1_KEY" && -f "$LEVEL1_CRT" ]] || { echo "Missing level1 key/cert ($LEVEL1_KEY, $LEVEL1_CRT)"; exit 1; }

mkdir -p "$OUTDIR/root" "$OUTDIR/level1"

cp -p "$ROOT_CRT" "$OUTDIR/root/root.crt.pem"
cp -p "$LEVEL1_KEY" "$OUTDIR/level1/level1.key.pem"
cp -p "$LEVEL1_CRT" "$OUTDIR/level1/level1.crt.pem"

echo "Signer export created in: $OUTDIR"
