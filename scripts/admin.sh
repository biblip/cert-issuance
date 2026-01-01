#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="${ROOT_DIR}/scripts"

clear_screen() {
  printf "\033c"
}

pause() {
  printf "\nPress Enter to continue..."
  read -r _
}

prompt() {
  local label="$1"
  local default="${2:-}"
  local value
  if [[ -n "$default" ]]; then
    read -r -p "${label} [${default}]: " value
    printf '%s' "${value:-$default}"
  else
    read -r -p "${label}: " value
    printf '%s' "$value"
  fi
}

prompt_secret() {
  local label="$1"
  local value
  read -r -s -p "${label}: " value
  printf "\n"
  printf '%s' "$value"
}

run_cmd() {
  printf "\n>> %s\n" "$*"
  "$@"
}

make_root() {
  local cn days bits
  cn="$(prompt "Root CN (blank for default)")"
  days="$(prompt "Root days (blank for default)")"
  bits="$(prompt "Root key bits (blank for default)")"
  run_cmd "${SCRIPTS_DIR}/make/00_make_root.sh" ${cn:+$cn} ${days:+$days} ${bits:+$bits}
}

make_level1() {
  local cn days bits
  cn="$(prompt "Level1 CN (blank for default)")"
  days="$(prompt "Level1 days (blank for default)")"
  bits="$(prompt "Level1 key bits (blank for default)")"
  run_cmd "${SCRIPTS_DIR}/make/01_make_level1.sh" ${cn:+$cn} ${days:+$days} ${bits:+$bits}
}

make_level2() {
  local cn days bits
  cn="$(prompt "Level2 CN (blank for default)")"
  days="$(prompt "Level2 days (blank for default)")"
  bits="$(prompt "Level2 key bits (blank for default)")"
  run_cmd "${SCRIPTS_DIR}/make/02_make_level2.sh" ${cn:+$cn} ${days:+$days} ${bits:+$bits}
}

make_level3_client() {
  local cn days bits
  cn="$(prompt "Level3 Client CN (blank for default)")"
  days="$(prompt "Level3 Client days (blank for default)")"
  bits="$(prompt "Level3 Client key bits (blank for default)")"
  run_cmd "${SCRIPTS_DIR}/make/03_make_level3_client.sh" ${cn:+$cn} ${days:+$days} ${bits:+$bits}
}

make_level3_server() {
  local cn days bits
  cn="$(prompt "Level3 Server CN (blank for default)")"
  days="$(prompt "Level3 Server days (blank for default)")"
  bits="$(prompt "Level3 Server key bits (blank for default)")"
  run_cmd "${SCRIPTS_DIR}/make/03_make_level3_server.sh" ${cn:+$cn} ${days:+$days} ${bits:+$bits}
}

make_full_chain() {
  run_cmd "${SCRIPTS_DIR}/make/00_make_root.sh"
  run_cmd "${SCRIPTS_DIR}/make/01_make_level1.sh"
  run_cmd "${SCRIPTS_DIR}/make/02_make_level2.sh"
  run_cmd "${SCRIPTS_DIR}/make/03_make_level3_client.sh"
  run_cmd "${SCRIPTS_DIR}/make/03_make_level3_server.sh"
}

issue_client() {
  local cn days bits
  cn="$(prompt "Client CN (blank for default)")"
  days="$(prompt "Client days (blank for default)")"
  bits="$(prompt "Client key bits (blank for default)")"
  run_cmd "${SCRIPTS_DIR}/make/04_make_client.sh" ${cn:+$cn} ${days:+$days} ${bits:+$bits}
}

issue_client_from_csr() {
  local name csr days
  name="$(prompt "Client name")"
  csr="$(prompt "CSR path")"
  days="$(prompt "Days (blank for default)")"
  run_cmd "${SCRIPTS_DIR}/make/04_make_client_from_csr.sh" "$name" "$csr" ${days:+$days}
}

issue_server() {
  local cn san days bits
  cn="$(prompt "Server CN")"
  san="$(prompt "Server SAN (e.g., DNS:api.example.local)")"
  days="$(prompt "Server days (blank for default)")"
  bits="$(prompt "Server key bits (blank for default)")"
  run_cmd "${SCRIPTS_DIR}/make/04_make_server.sh" "$cn" "$san" ${days:+$days} ${bits:+$bits}
}

issue_server_from_csr() {
  local name csr san days
  name="$(prompt "Server name")"
  csr="$(prompt "CSR path")"
  san="$(prompt "SAN (e.g., DNS:api.example.local)")"
  days="$(prompt "Days (blank for default)")"
  run_cmd "${SCRIPTS_DIR}/make/04_make_server_from_csr.sh" "$name" "$csr" ${san:+$san} ${days:+$days}
}

export_root() {
  run_cmd "${SCRIPTS_DIR}/export/00_export_root.sh"
}

export_signer_level1() {
  run_cmd "${SCRIPTS_DIR}/export/01_export_signer_level1.sh"
}

export_signer_level2() {
  run_cmd "${SCRIPTS_DIR}/export/02_export_signer_level2.sh"
}

export_signer_level3_client() {
  run_cmd "${SCRIPTS_DIR}/export/03_export_signer_level3_client.sh"
}

export_signer_level3_server() {
  run_cmd "${SCRIPTS_DIR}/export/03_export_signer_level3_server.sh"
}

export_client() {
  local name
  name="$(prompt "Client name")"
  run_cmd "${SCRIPTS_DIR}/export/04_export_client.sh" "$name"
}

export_server() {
  local name alias password
  name="$(prompt "Server name")"
  alias="$(prompt "Alias (blank for default)")"
  password="$(prompt_secret "Password (blank to use P12_PASSWORD)")"
  if [[ -n "$password" ]]; then
    P12_PASSWORD="$password" run_cmd "${SCRIPTS_DIR}/export/04_export_server.sh" "$name" ${alias:+$alias} "$password"
  else
    run_cmd "${SCRIPTS_DIR}/export/04_export_server.sh" "$name" ${alias:+$alias}
  fi
}

import_root() {
  local bundle
  bundle="$(prompt "Bundle dir (blank for default trust-bundles)")"
  run_cmd "${SCRIPTS_DIR}/import/00_import_root.sh" ${bundle:+$bundle}
}

import_level1() {
  local bundle
  bundle="$(prompt "Bundle dir (blank for default trust-bundles)")"
  run_cmd "${SCRIPTS_DIR}/import/01_import_level1.sh" ${bundle:+$bundle}
}

import_level2() {
  local bundle
  bundle="$(prompt "Bundle dir (blank for default trust-bundles)")"
  run_cmd "${SCRIPTS_DIR}/import/02_import_level2.sh" ${bundle:+$bundle}
}

import_level3_client() {
  local bundle
  bundle="$(prompt "Bundle dir (blank for default trust-bundles)")"
  run_cmd "${SCRIPTS_DIR}/import/03_import_level3_client.sh" ${bundle:+$bundle}
}

import_level3_server() {
  local bundle
  bundle="$(prompt "Bundle dir (blank for default trust-bundles)")"
  run_cmd "${SCRIPTS_DIR}/import/03_import_level3_server.sh" ${bundle:+$bundle}
}

menu_make() {
  while true; do
    clear_screen
    printf "PKI Admin - Make CAs\n"
    printf "1) Make Root\n"
    printf "2) Make Level1\n"
    printf "3) Make Level2\n"
    printf "4) Make Level3 Client\n"
    printf "5) Make Level3 Server\n"
    printf "6) Make Full Chain\n"
    printf "0) Back\n"
    read -r -p "Select: " choice
    case "$choice" in
      1) make_root; pause ;;
      2) make_level1; pause ;;
      3) make_level2; pause ;;
      4) make_level3_client; pause ;;
      5) make_level3_server; pause ;;
      6) make_full_chain; pause ;;
      0) return ;;
      *) printf "Invalid choice\n"; pause ;;
    esac
  done
}

menu_issue() {
  while true; do
    clear_screen
    printf "PKI Admin - Issue Certs\n"
    printf "1) Issue Client Cert\n"
    printf "2) Issue Client Cert from CSR\n"
    printf "3) Issue Server Cert\n"
    printf "4) Issue Server Cert from CSR\n"
    printf "0) Back\n"
    read -r -p "Select: " choice
    case "$choice" in
      1) issue_client; pause ;;
      2) issue_client_from_csr; pause ;;
      3) issue_server; pause ;;
      4) issue_server_from_csr; pause ;;
      0) return ;;
      *) printf "Invalid choice\n"; pause ;;
    esac
  done
}

menu_export() {
  while true; do
    clear_screen
    printf "PKI Admin - Export Bundles\n"
    printf "1) Export Root\n"
    printf "2) Export Signer Level1\n"
    printf "3) Export Signer Level2\n"
    printf "4) Export Signer Level3 Client\n"
    printf "5) Export Signer Level3 Server\n"
    printf "6) Export Client PKCS#12\n"
    printf "7) Export Server PKCS#12\n"
    printf "0) Back\n"
    read -r -p "Select: " choice
    case "$choice" in
      1) export_root; pause ;;
      2) export_signer_level1; pause ;;
      3) export_signer_level2; pause ;;
      4) export_signer_level3_client; pause ;;
      5) export_signer_level3_server; pause ;;
      6) export_client; pause ;;
      7) export_server; pause ;;
      0) return ;;
      *) printf "Invalid choice\n"; pause ;;
    esac
  done
}

menu_import() {
  while true; do
    clear_screen
    printf "PKI Admin - Import Bundles\n"
    printf "1) Import Root\n"
    printf "2) Import Level1\n"
    printf "3) Import Level2\n"
    printf "4) Import Level3 Client\n"
    printf "5) Import Level3 Server\n"
    printf "0) Back\n"
    read -r -p "Select: " choice
    case "$choice" in
      1) import_root; pause ;;
      2) import_level1; pause ;;
      3) import_level2; pause ;;
      4) import_level3_client; pause ;;
      5) import_level3_server; pause ;;
      0) return ;;
      *) printf "Invalid choice\n"; pause ;;
    esac
  done
}

main_menu() {
  while true; do
    clear_screen
    printf "PKI Admin\n"
    printf "1) Make CAs\n"
    printf "2) Issue Certs\n"
    printf "3) Export Bundles\n"
    printf "4) Import Bundles\n"
    printf "0) Exit\n"
    read -r -p "Select: " choice
    case "$choice" in
      1) menu_make ;;
      2) menu_issue ;;
      3) menu_export ;;
      4) menu_import ;;
      0) exit 0 ;;
      *) printf "Invalid choice\n"; pause ;;
    esac
  done
}

main_menu
