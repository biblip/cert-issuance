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
- `scripts/`: CA/client creation plus export/import helpers
- `root/`, `level1/`, `level2/`, `level3/`: CA keys/certs/CSRs
- `client/`: per-client keys/certs/CSRs
- `trust-bundles/`: exported artifacts for distribution

## Primary scripts

- `scripts/make/00_make_root.sh`: create root CA
- `scripts/make/01_make_level1.sh`: create level 1 CA signed by root
- `scripts/make/02_make_level2.sh`: create level 2 CA signed by level 1
- `scripts/make/03_make_level3.sh`: create level 3 CA signed by level 2
- `scripts/make/04_make_client.sh`: issue a client certificate from level 3
- `scripts/make/04_make_client_from_csr.sh`: sign an external CSR with level 3

## Export scripts

- `scripts/export/00_export_root.sh`: export root cert to `trust-bundles/root/`
- `scripts/export/01_export_signer_level1.sh`: export root cert + level 1 signer key/cert
- `scripts/export/02_export_signer_level2.sh`: export root/level1 certs + level 2 signer key/cert
- `scripts/export/03_export_signer_level3.sh`: export root/level1/level2 certs + level 3 signer key/cert
- `scripts/export/04_export_client.sh`: export client key/cert to `trust-bundles/client/<name>/`

## Import scripts

- `scripts/import/00_import_root.sh`: import root cert bundle to `root/certs/`
- `scripts/import/01_import_level1.sh`: import level 1 key/cert bundle
- `scripts/import/02_import_level2.sh`: import level 2 key/cert bundle
- `scripts/import/03_import_level3.sh`: import level 3 key/cert bundle

All level import scripts require both key and cert; they refuse to import
partial bundles. When they do run, they also import any public certs present
in the trust bundle into their respective `*/certs` directories.

## Defaults and overrides

- Defaults live in `conf/ca_ext.cnf` under `[ defaults ]`.
- CA creation scripts accept overrides: `[cn] [days] [key_bits]`.
- Client creation accepts `[client_cn] [days] [key_bits]`.

Examples:

```bash
./scripts/make/00_make_root.sh
./scripts/make/01_make_level1.sh
./scripts/make/02_make_level2.sh
./scripts/make/03_make_level3.sh

./scripts/make/04_make_client.sh "client-001"
./scripts/make/04_make_client_from_csr.sh "client-001" /path/to/client.csr.pem

./scripts/export/00_export_root.sh
./scripts/export/01_export_signer_level1.sh
./scripts/export/02_export_signer_level2.sh
./scripts/export/03_export_signer_level3.sh
./scripts/export/04_export_client.sh "client-001"

./scripts/import/00_import_root.sh
./scripts/import/01_import_level1.sh
./scripts/import/02_import_level2.sh
./scripts/import/03_import_level3.sh
```

## Safety notes

- Scripts refuse to overwrite existing keys/certs.
- Clean or rename artifacts if you need to regenerate them.
