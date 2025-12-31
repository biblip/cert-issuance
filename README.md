# PKI Builder

This directory contains a small OpenSSL-based PKI toolchain for generating a
root CA, three intermediate CA levels, and client certificates. Defaults are
stored in `conf/ca_ext.cnf` and each script can take overrides via CLI args.

## Requirements

- OpenSSL available on your PATH

## Layout

- `conf/ca_ext.cnf`: shared extensions and default CN/days/key bits
- `scripts/`: make/export/import helpers (see subdirectories)
- `root/`, `level1/`, `level2/`, `level3/`: CA keys/certs/CSRs
- `client/`: per-client keys/certs/CSRs
- `trust-bundles/`: exported artifacts for distribution

## Quick start

Create a full chain (root -> level1 -> level2 -> level3):

```bash
./scripts/make/00_make_root.sh
./scripts/make/01_make_level1.sh
./scripts/make/02_make_level2.sh
./scripts/make/03_make_level3.sh
```

Issue a client certificate signed by the level 3 CA:

```bash
./scripts/make/04_make_client.sh "client-001"
```

Sign an existing CSR:

```bash
./scripts/make/04_make_client_from_csr.sh "client-001" /path/to/client.csr.pem
```

Export root trust bundle:

```bash
./scripts/export/00_export_root.sh
```

Export trust bundles for a signer level (creates `trust-bundles/` once):

```bash
./scripts/export/01_export_signer_level1.sh
./scripts/export/02_export_signer_level2.sh
./scripts/export/03_export_signer_level3.sh
```

Export a client key/cert bundle:

```bash
./scripts/export/04_export_client.sh "client-001"
```

Import trust bundles (requires full key+cert for level signers; imports all public certs present):

```bash
./scripts/import/00_import_root.sh
./scripts/import/01_import_level1.sh
./scripts/import/02_import_level2.sh
./scripts/import/03_import_level3.sh
```

## Script arguments

Each CA creation script accepts optional overrides in the form:

```bash
./scripts/make/00_make_root.sh [cn] [days] [key_bits]
./scripts/make/01_make_level1.sh [cn] [days] [key_bits]
./scripts/make/02_make_level2.sh [cn] [days] [key_bits]
./scripts/make/03_make_level3.sh [cn] [days] [key_bits]
```

The client script accepts:

```bash
./scripts/make/04_make_client.sh [client_cn] [days] [key_bits]
```

Defaults are pulled from `conf/ca_ext.cnf` when arguments are omitted. Scripts
refuse to overwrite existing keys/certs, so clean or rename artifacts if you
need to regenerate them. Export scripts also refuse to run if `trust-bundles/`
already exists; delete it manually to re-export.
