#!/usr/bin/env bash
set -euo pipefail

OUTDIR="trust-bundles/root"

ROOT_CRT="root/certs/root.crt.pem"

mkdir -p "$OUTDIR"

[[ -f "$ROOT_CRT" ]] || { echo "Missing root cert ($ROOT_CRT)"; exit 1; }

cp -p "$ROOT_CRT" "$OUTDIR/root.crt.pem"

echo "Root certificate exported to: $OUTDIR/root.crt.pem"
