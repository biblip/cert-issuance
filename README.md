# PKI Builder

This directory contains a small OpenSSL-based PKI toolchain for generating a
root CA, three intermediate CA levels, and client certificates. Defaults are
stored in `conf/ca_ext.cnf` and each script can take overrides via CLI args.

## Requirements

- OpenSSL available on your PATH

## Layout

- `conf/ca_ext.cnf`: shared extensions and default CN/days/key bits
- `scripts/`: build and export helpers
- `root/`, `level1/`, `level2/`, `level3/`: CA keys/certs/CSRs
- `client/`: per-client keys/certs/CSRs
- `trust-bundles/`: exported artifacts for distribution

## Quick start

Create a full chain (root -> level1 -> level2 -> level3):

```bash
./scripts/00_make_root.sh
./scripts/01_make_level1.sh
./scripts/02_make_level2.sh
./scripts/03_make_level3.sh
```

Issue a client certificate signed by the level 3 CA:

```bash
./scripts/04_make_client.sh "client-001"
```

Sign an existing CSR:

```bash
./scripts/04_make_client_from_csr.sh "client-001" /path/to/client.csr.pem
```

Export trust bundles:

```bash
./scripts/00_export_root.sh
./scripts/01_export_level1.sh
./scripts/02_export_level2.sh
./scripts/03_export_level3.sh
```

## Script arguments

Each CA creation script accepts optional overrides in the form:

```bash
./scripts/00_make_root.sh [cn] [days] [key_bits]
./scripts/01_make_level1.sh [cn] [days] [key_bits]
./scripts/02_make_level2.sh [cn] [days] [key_bits]
./scripts/03_make_level3.sh [cn] [days] [key_bits]
```

The client script accepts:

```bash
./scripts/04_make_client.sh [client_cn] [days] [key_bits]
```

Defaults are pulled from `conf/ca_ext.cnf` when arguments are omitted. Scripts
refuse to overwrite existing keys/certs, so clean or rename artifacts if you
need to regenerate them.
