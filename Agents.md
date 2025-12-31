# Agents Guide: PKI Builder

This project provides a small OpenSSL-based toolchain that builds a PKI with a
root CA, three intermediate CA levels, and client certificates. It also exports
trust bundles for distribution.

## What this project does

- Creates a root CA (self-signed)
- Creates three intermediate CAs (level1 -> level2 -> level3)
- Issues client certificates signed by the level 3 CA
- Exports trust bundles for each CA level

## Layout

- `conf/ca_ext.cnf`: shared X.509 extensions and default CN/days/key bits
- `scripts/`: CA and client creation plus export helpers
- `root/`, `level1/`, `level2/`, `level3/`: CA keys/certs/CSRs
- `client/`: per-client keys/certs/CSRs
- `trust-bundles/`: exported artifacts for distribution

## Primary scripts

- `scripts/00_make_root.sh`: create root CA
- `scripts/01_make_level1.sh`: create level 1 CA signed by root
- `scripts/02_make_level2.sh`: create level 2 CA signed by level 1
- `scripts/03_make_level3.sh`: create level 3 CA signed by level 2
- `scripts/04_make_client.sh`: issue a client certificate from level 3
- `scripts/04_make_client_from_csr.sh`: sign an external CSR with level 3

## Export scripts

- `scripts/00_export_root.sh`: export root cert to `trust-bundles/root/`
- `scripts/01_export_level1.sh`: export level 1 key/cert
- `scripts/02_export_level2.sh`: export level 2 key/cert
- `scripts/03_export_level3.sh`: export level 3 key/cert

## Import scripts

- `scripts/00_import_root.sh`: import root cert bundle to `root/certs/`
- `scripts/01_import_level1.sh`: import level 1 key/cert bundle
- `scripts/02_import_level2.sh`: import level 2 key/cert bundle
- `scripts/03_import_level3.sh`: import level 3 key/cert bundle

## Defaults and overrides

- Defaults live in `conf/ca_ext.cnf` under `[ defaults ]`.
- CA creation scripts accept overrides: `[cn] [days] [key_bits]`.
- Client creation accepts `[client_cn] [days] [key_bits]`.

Examples:

```bash
./scripts/00_make_root.sh
./scripts/01_make_level1.sh
./scripts/02_make_level2.sh
./scripts/03_make_level3.sh

./scripts/04_make_client.sh "client-001"
./scripts/04_make_client_from_csr.sh "client-001" /path/to/client.csr.pem

./scripts/00_export_root.sh
./scripts/01_export_level1.sh
./scripts/02_export_level2.sh
./scripts/03_export_level3.sh

./scripts/00_import_root.sh
./scripts/01_import_level1.sh
./scripts/02_import_level2.sh
./scripts/03_import_level3.sh
```

## Safety notes

- Scripts refuse to overwrite existing keys/certs.
- Clean or rename artifacts if you need to regenerate them.
