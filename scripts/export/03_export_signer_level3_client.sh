#!/usr/bin/env bash
set -euo pipefail

OUTDIR="trust-bundles"

ROOT_CRT="root/certs/root.crt.pem"
LEVEL1_CRT="level1/certs/level1.crt.pem"
LEVEL2_CRT="level2/certs/level2.crt.pem"
LEVEL3_KEY="level3-client/private/level3-client.key.pem"
LEVEL3_CRT="level3-client/certs/level3-client.crt.pem"

if [[ -d "$OUTDIR" ]]; then
  echo "Warning: export target already exists (${OUTDIR}); delete it to re-export."
  exit 0
fi

[[ -f "$ROOT_CRT" ]] || { echo "Missing root cert ($ROOT_CRT)"; exit 1; }
[[ -f "$LEVEL1_CRT" ]] || { echo "Missing level1 cert ($LEVEL1_CRT)"; exit 1; }
[[ -f "$LEVEL2_CRT" ]] || { echo "Missing level2 cert ($LEVEL2_CRT)"; exit 1; }
[[ -f "$LEVEL3_KEY" && -f "$LEVEL3_CRT" ]] || { echo "Missing level3 client key/cert ($LEVEL3_KEY, $LEVEL3_CRT)"; exit 1; }

mkdir -p "$OUTDIR/root" "$OUTDIR/level1" "$OUTDIR/level2" "$OUTDIR/level3-client"

cp -p "$ROOT_CRT" "$OUTDIR/root/root.crt.pem"
cp -p "$LEVEL1_CRT" "$OUTDIR/level1/level1.crt.pem"
cp -p "$LEVEL2_CRT" "$OUTDIR/level2/level2.crt.pem"
cp -p "$LEVEL3_KEY" "$OUTDIR/level3-client/level3-client.key.pem"
cp -p "$LEVEL3_CRT" "$OUTDIR/level3-client/level3-client.crt.pem"

echo "Signer export created in: $OUTDIR"
