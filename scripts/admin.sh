#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="${ROOT_DIR}/scripts"
HISTORY_FILE="${ROOT_DIR}/.admin_history"
EXTFILE="${ROOT_DIR}/conf/ca_ext.cnf"
USB_ROOT="/media/${USER:-$(id -un)}"

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
    value="${value:-$default}"
  else
    read -r -p "${label}: " value
  fi
  printf '%s' "$(sanitize_input "$value")"
}

prompt_secret() {
  local label="$1"
  local value
  read -r -s -p "${label}: " value
  printf "\n"
  printf '%s' "$(sanitize_input "$value")"
}

sanitize_input() {
  local value="$1"
  value="$(printf '%s' "$value" | tr -d '\r\n')"
  value="$(printf '%s' "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  printf '%s' "$value"
}

sanitize_number() {
  local value="$1"
  value="$(sanitize_input "$value")"
  value="$(printf '%s' "$value" | tr -cd '0-9')"
  printf '%s' "$value"
}

sanitize_name() {
  printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_' | tr -s '_' '_'
}

conf_get() {
  local key="$1"
  awk -F' *= *' -v section="defaults" -v key="$key" '
    $0 ~ "^\\[" section "\\]" { in_section=1; next }
    $0 ~ "^\\[" { in_section=0 }
    in_section && $1 == key { print $2; exit }
  ' "$EXTFILE"
}

usb_list() {
  mount | awk -v user="$USER" '$3 ~ "^/media/"user"/" {print $3}' | sort -u
}

usb_csr_roots() {
  local m
  local -a mounts
  mapfile -t mounts < <(usb_list)
  for m in "${mounts[@]}"; do
    if [[ -d "$m/csr-list" ]]; then
      printf '%s/csr-list\n' "$m"
    fi
  done
}

parse_kv_config() {
  local file="$1"
  local line key val
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    key="${line%%=*}"
    val="${line#*=}"
    key="$(printf '%s' "$key" | tr -d '[:space:]')"
    val="$(printf '%s' "$val" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    case "$key" in
      type|name|csr|san|days|alias|password) printf '%s=%s\n' "$key" "$val" ;;
    esac
  done < "$file"
}

load_csr_request() {
  local dir="$1"
  local cfg="$dir/config.conf"
  local kv
  if [[ ! -f "$cfg" ]]; then
    printf "Missing config.conf in %s\n" "$dir"
    return 1
  fi
  while IFS= read -r kv; do
    case "$kv" in
      type=*) CSR_TYPE="${kv#type=}" ;;
      name=*) CSR_NAME="${kv#name=}" ;;
      csr=*) CSR_PATH="${kv#csr=}" ;;
      san=*) CSR_SAN="${kv#san=}" ;;
      days=*) CSR_DAYS="${kv#days=}" ;;
      alias=*) CSR_ALIAS="${kv#alias=}" ;;
      password=*) CSR_PASSWORD="${kv#password=}" ;;
    esac
  done < <(parse_kv_config "$cfg")
  if [[ -z "${CSR_TYPE:-}" || -z "${CSR_NAME:-}" ]]; then
    printf "Missing required fields in %s (type, name)\n" "$cfg"
    return 1
  fi
  if [[ -z "${CSR_PATH:-}" ]]; then
    CSR_PATH="$(find "$dir" -maxdepth 1 -type f \( -name "*.csr.pem" -o -name "*.csr" \) | head -n1)"
  else
    CSR_PATH="$dir/$CSR_PATH"
  fi
  if [[ ! -f "$CSR_PATH" ]]; then
    printf "Missing CSR file in %s\n" "$dir"
    return 1
  fi
  if [[ -z "${CSR_DAYS:-}" ]]; then
    if [[ "$CSR_TYPE" == "server" ]]; then
      CSR_DAYS="$(conf_get server_days)"
    else
      CSR_DAYS="$(conf_get client_days)"
    fi
  fi
  if [[ "$CSR_TYPE" == "server" && -z "${CSR_SAN:-}" ]]; then
    CSR_SAN="$(conf_get server_san)"
  fi
  return 0
}

export_chain_to_dir() {
  local type="$1"
  local name="$2"
  local dest_dir="$3"
  local alias="$4"
  local password="$5"
  local safe_name key crt chain_tmp out_p12 out_p7b
  safe_name="$(sanitize_name "$name")"
  if [[ "$type" == "server" ]]; then
    key="${ROOT_DIR}/output/server/${safe_name}/private/${safe_name}.key.pem"
    crt="${ROOT_DIR}/output/server/${safe_name}/cert/${safe_name}.crt.pem"
  else
    key="${ROOT_DIR}/output/client/${safe_name}/private/${safe_name}.key.pem"
    crt="${ROOT_DIR}/output/client/${safe_name}/cert/${safe_name}.crt.pem"
  fi
  out_p12="${dest_dir}/${safe_name}.p12"
  out_p7b="${dest_dir}/${safe_name}.p7b"
  chain_tmp=""
  chain_tmp="$(mktemp)"
  trap 'rm -f "${chain_tmp:-}"' RETURN
  cat /dev/null > "$chain_tmp"
  if [[ "$type" == "server" ]]; then
    [[ -f "${ROOT_DIR}/level3-server/certs/level3-server.crt.pem" ]] && cat "${ROOT_DIR}/level3-server/certs/level3-server.crt.pem" >> "$chain_tmp"
  else
    [[ -f "${ROOT_DIR}/level3-client/certs/level3-client.crt.pem" ]] && cat "${ROOT_DIR}/level3-client/certs/level3-client.crt.pem" >> "$chain_tmp"
  fi
  [[ -f "${ROOT_DIR}/level2/certs/level2.crt.pem" ]] && cat "${ROOT_DIR}/level2/certs/level2.crt.pem" >> "$chain_tmp"
  [[ -f "${ROOT_DIR}/level1/certs/level1.crt.pem" ]] && cat "${ROOT_DIR}/level1/certs/level1.crt.pem" >> "$chain_tmp"
  [[ -f "${ROOT_DIR}/root/certs/root.crt.pem" ]] && cat "${ROOT_DIR}/root/certs/root.crt.pem" >> "$chain_tmp"
  if [[ -f "$key" ]]; then
    if [[ -z "$password" ]]; then
      printf "Missing password for %s; skipping PKCS#12.\n" "$name"
    else
      if [[ -s "$chain_tmp" ]]; then
        openssl pkcs12 -export \
          -name "$alias" \
          -inkey "$key" \
          -in "$crt" \
          -certfile "$chain_tmp" \
          -out "$out_p12" \
          -passout pass:"$password"
      else
        openssl pkcs12 -export \
          -name "$alias" \
          -inkey "$key" \
          -in "$crt" \
          -out "$out_p12" \
          -passout pass:"$password"
      fi
      printf "Exported PKCS#12: %s\n" "$out_p12"
    fi
  else
    if [[ -s "$chain_tmp" ]]; then
      cat "$crt" "$chain_tmp" | openssl crl2pkcs7 -nocrl -certfile /dev/stdin -out "$out_p7b"
    else
      openssl crl2pkcs7 -nocrl -certfile "$crt" -out "$out_p7b"
    fi
    printf "Exported P7B: %s\n" "$out_p7b"
  fi
}

issue_from_usb() {
  local csr_root dir
  local -a roots
  local count=0
  printf "USB scan (verbose): mounts under %s\n" "$USB_ROOT"
  mapfile -t roots < <(usb_csr_roots)
  if [[ ${#roots[@]} -eq 0 ]]; then
    printf "USB scan (verbose): no csr-list directories found.\n"
    pause
    return
  fi
  printf "USB scan (verbose): csr-list directories:\n"
  printf "%s\n" "${roots[@]}"
  for csr_root in "${roots[@]}"; do
    for dir in "$csr_root"/*; do
      [[ -d "$dir" ]] || continue
      CSR_TYPE=""; CSR_NAME=""; CSR_PATH=""; CSR_SAN=""; CSR_DAYS=""; CSR_ALIAS=""; CSR_PASSWORD=""
      if ! load_csr_request "$dir"; then
        printf "Skipping %s\n" "$dir"
        continue
      fi
      printf "\nSigning %s (%s)\n" "$CSR_NAME" "$CSR_TYPE"
      if [[ "$CSR_TYPE" == "server" ]]; then
        run_cmd "Issue Server from CSR (USB)" 0 "${SCRIPTS_DIR}/make/04_make_server_from_csr.sh" "$CSR_NAME" "$CSR_PATH" "${CSR_SAN}" "${CSR_DAYS}"
      elif [[ "$CSR_TYPE" == "client" ]]; then
        run_cmd "Issue Client from CSR (USB)" 0 "${SCRIPTS_DIR}/make/04_make_client_from_csr.sh" "$CSR_NAME" "$CSR_PATH" "${CSR_DAYS}"
      else
        printf "Unknown type '%s' in %s\n" "$CSR_TYPE" "$dir"
        continue
      fi
      mkdir -p "$dir"
      local safe_name cert_path
      safe_name="$(sanitize_name "$CSR_NAME")"
      if [[ "$CSR_TYPE" == "server" ]]; then
        cert_path="${ROOT_DIR}/output/server/${safe_name}/cert/${safe_name}.crt.pem"
      else
        cert_path="${ROOT_DIR}/output/client/${safe_name}/cert/${safe_name}.crt.pem"
      fi
      if [[ -f "$cert_path" ]]; then
        cp -p "$cert_path" "$dir/${safe_name}.crt.pem"
      fi
      export_chain_to_dir "$CSR_TYPE" "$CSR_NAME" "$dir" "${CSR_ALIAS:-$safe_name}" "${CSR_PASSWORD:-}"
      count=$((count+1))
    done
  done
  printf "\nProcessed %d request(s).\n" "$count"
  pause
}

build_cmd_string() {
  local arg
  local out=""
  for arg in "$@"; do
    out+=$(printf '%q ' "$arg")
  done
  printf '%s' "${out% }"
}

record_history() {
  local label="$1"
  local needs_password="$2"
  local cmd_string="$3"
  local ts
  ts="$(date +%Y-%m-%dT%H:%M:%S)"
  printf '%s|%s|%s|%s\n' "$ts" "$label" "$needs_password" "$cmd_string" >> "$HISTORY_FILE"
}

run_history_command() {
  local label="$1"
  local needs_password="$2"
  local password="${3:-}"
  shift 3
  local cmd_string
  cmd_string="$(build_cmd_string "$@")"
  printf "\n>> %s\n" "$cmd_string"
  if [[ "$needs_password" == "1" && -n "$password" ]]; then
    P12_PASSWORD="$password"
  fi
  if [[ -n "${P12_PASSWORD+x}" ]]; then
    export P12_PASSWORD
  fi
  "$@"
  record_history "$label" "$needs_password" "$cmd_string"
}

run_cmd() {
  local label="$1"
  local needs_password="$2"
  shift 2
  local cmd_string
  cmd_string="$(build_cmd_string "$@")"
  printf "\n>> %s\n" "$cmd_string"
  if [[ -n "${P12_PASSWORD+x}" ]]; then
    export P12_PASSWORD
  fi
  "$@"
  record_history "$label" "$needs_password" "$cmd_string"
}

status_mark() {
  if [[ -e "$1" ]]; then
    printf "[x]"
  else
    printf "[ ]"
  fi
}

count_dirs() {
  local dir="$1"
  if [[ -d "$dir" ]]; then
    find "$dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' '
  else
    printf "0"
  fi
}

count_files() {
  local dir="$1"
  local pattern="$2"
  if [[ -d "$dir" ]]; then
    find "$dir" -type f -name "$pattern" 2>/dev/null | wc -l | tr -d ' '
  else
    printf "0"
  fi
}

print_ca_status() {
  printf "CAs:\n"
  printf "  %s Root\n" "$(status_mark "${ROOT_DIR}/root/certs/root.crt.pem")"
  printf "  %s Level1\n" "$(status_mark "${ROOT_DIR}/level1/certs/level1.crt.pem")"
  printf "  %s Level2\n" "$(status_mark "${ROOT_DIR}/level2/certs/level2.crt.pem")"
  printf "  %s Level3 Client\n" "$(status_mark "${ROOT_DIR}/level3-client/certs/level3-client.crt.pem")"
  printf "  %s Level3 Server\n" "$(status_mark "${ROOT_DIR}/level3-server/certs/level3-server.crt.pem")"
}

print_endpoint_status() {
  printf "Endpoints:\n"
  printf "  Clients: %s\n" "$(count_dirs "${ROOT_DIR}/output/client")"
  printf "  Servers: %s\n" "$(count_dirs "${ROOT_DIR}/output/server")"
}

print_bundle_status() {
  if [[ -d "${ROOT_DIR}/trust-bundles" ]]; then
    printf "Bundles: present (delete trust-bundles/ to re-export)\n"
  else
    printf "Bundles: none\n"
  fi
  printf "  Client PKCS#12: %s\n" "$(count_files "${ROOT_DIR}/trust-bundles/client" "*.p12")"
  printf "  Client P7B    : %s\n" "$(count_files "${ROOT_DIR}/trust-bundles/client" "*.p7b")"
  printf "  Server PKCS#12: %s\n" "$(count_files "${ROOT_DIR}/trust-bundles/server" "*.p12")"
  printf "  Server P7B    : %s\n" "$(count_files "${ROOT_DIR}/trust-bundles/server" "*.p7b")"
}

print_header() {
  printf '%s\n' "============================================"
  printf '%s\n' "$1"
  printf '%s\n' "--------------------------------------------"
}

make_root() {
  local cn days bits
  cn="$(prompt "Root CN" "$(conf_get root_cn)")"
  days="$(sanitize_number "$(prompt "Root days" "$(conf_get root_days)")")"
  bits="$(sanitize_number "$(prompt "Root key bits" "$(conf_get root_key_bits)")")"
  local args=()
  [[ -n "$cn" ]] && args+=("$cn")
  [[ -n "$days" ]] && args+=("$days")
  [[ -n "$bits" ]] && args+=("$bits")
  run_cmd "Make Root" 0 "${SCRIPTS_DIR}/make/00_make_root.sh" "${args[@]}"
}

make_level1() {
  local cn days bits
  cn="$(prompt "Level1 CN" "$(conf_get level1_cn)")"
  days="$(sanitize_number "$(prompt "Level1 days" "$(conf_get level1_days)")")"
  bits="$(sanitize_number "$(prompt "Level1 key bits" "$(conf_get level1_key_bits)")")"
  local args=()
  [[ -n "$cn" ]] && args+=("$cn")
  [[ -n "$days" ]] && args+=("$days")
  [[ -n "$bits" ]] && args+=("$bits")
  run_cmd "Make Level1" 0 "${SCRIPTS_DIR}/make/01_make_level1.sh" "${args[@]}"
}

make_level2() {
  local cn days bits
  cn="$(prompt "Level2 CN" "$(conf_get level2_cn)")"
  days="$(sanitize_number "$(prompt "Level2 days" "$(conf_get level2_days)")")"
  bits="$(sanitize_number "$(prompt "Level2 key bits" "$(conf_get level2_key_bits)")")"
  local args=()
  [[ -n "$cn" ]] && args+=("$cn")
  [[ -n "$days" ]] && args+=("$days")
  [[ -n "$bits" ]] && args+=("$bits")
  run_cmd "Make Level2" 0 "${SCRIPTS_DIR}/make/02_make_level2.sh" "${args[@]}"
}

make_level3_client() {
  local cn days bits
  cn="$(prompt "Level3 Client CN" "$(conf_get level3_client_cn)")"
  days="$(sanitize_number "$(prompt "Level3 Client days" "$(conf_get level3_client_days)")")"
  bits="$(sanitize_number "$(prompt "Level3 Client key bits" "$(conf_get level3_client_key_bits)")")"
  local args=()
  [[ -n "$cn" ]] && args+=("$cn")
  [[ -n "$days" ]] && args+=("$days")
  [[ -n "$bits" ]] && args+=("$bits")
  run_cmd "Make Level3 Client" 0 "${SCRIPTS_DIR}/make/03_make_level3_client.sh" "${args[@]}"
}

make_level3_server() {
  local cn days bits
  cn="$(prompt "Level3 Server CN" "$(conf_get level3_server_cn)")"
  days="$(sanitize_number "$(prompt "Level3 Server days" "$(conf_get level3_server_days)")")"
  bits="$(sanitize_number "$(prompt "Level3 Server key bits" "$(conf_get level3_server_key_bits)")")"
  local args=()
  [[ -n "$cn" ]] && args+=("$cn")
  [[ -n "$days" ]] && args+=("$days")
  [[ -n "$bits" ]] && args+=("$bits")
  run_cmd "Make Level3 Server" 0 "${SCRIPTS_DIR}/make/03_make_level3_server.sh" "${args[@]}"
}

make_full_chain() {
  run_cmd "Make Root" 0 "${SCRIPTS_DIR}/make/00_make_root.sh"
  run_cmd "Make Level1" 0 "${SCRIPTS_DIR}/make/01_make_level1.sh"
  run_cmd "Make Level2" 0 "${SCRIPTS_DIR}/make/02_make_level2.sh"
  run_cmd "Make Level3 Client" 0 "${SCRIPTS_DIR}/make/03_make_level3_client.sh"
  run_cmd "Make Level3 Server" 0 "${SCRIPTS_DIR}/make/03_make_level3_server.sh"
}

issue_client() {
  local cn days bits
  cn="$(prompt "Client CN" "$(conf_get client_cn)")"
  days="$(sanitize_number "$(prompt "Client days" "$(conf_get client_days)")")"
  bits="$(sanitize_number "$(prompt "Client key bits" "$(conf_get client_key_bits)")")"
  local args=()
  [[ -n "$cn" ]] && args+=("$cn")
  [[ -n "$days" ]] && args+=("$days")
  [[ -n "$bits" ]] && args+=("$bits")
  run_cmd "Issue Client" 0 "${SCRIPTS_DIR}/make/04_make_client.sh" "${args[@]}"
}

issue_client_from_csr() {
  local name csr days
  name="$(prompt "Client name")"
  csr="$(prompt "CSR path")"
  days="$(sanitize_number "$(prompt "Days" "$(conf_get client_days)")")"
  local args=("$name" "$csr")
  [[ -n "$days" ]] && args+=("$days")
  run_cmd "Issue Client from CSR" 0 "${SCRIPTS_DIR}/make/04_make_client_from_csr.sh" "${args[@]}"
}

issue_server() {
  local cn san days bits
  cn="$(prompt "Server CN")"
  san="$(prompt "Server SAN (e.g., DNS:api.example.local)" "$(conf_get server_san)")"
  days="$(sanitize_number "$(prompt "Server days" "$(conf_get server_days)")")"
  bits="$(sanitize_number "$(prompt "Server key bits" "$(conf_get server_key_bits)")")"
  local args=("$cn" "$san")
  [[ -n "$days" ]] && args+=("$days")
  [[ -n "$bits" ]] && args+=("$bits")
  run_cmd "Issue Server" 0 "${SCRIPTS_DIR}/make/04_make_server.sh" "${args[@]}"
}

issue_server_from_csr() {
  local name csr san days
  name="$(prompt "Server name")"
  csr="$(prompt "CSR path")"
  san="$(prompt "SAN (e.g., DNS:api.example.local)" "$(conf_get server_san)")"
  days="$(sanitize_number "$(prompt "Days" "$(conf_get server_days)")")"
  local args=("$name" "$csr")
  [[ -n "$san" ]] && args+=("$san")
  [[ -n "$days" ]] && args+=("$days")
  run_cmd "Issue Server from CSR" 0 "${SCRIPTS_DIR}/make/04_make_server_from_csr.sh" "${args[@]}"
}

export_root() {
  run_cmd "Export Root" 0 "${SCRIPTS_DIR}/export/00_export_root.sh"
}

export_signer_level1() {
  run_cmd "Export Signer Level1" 0 "${SCRIPTS_DIR}/export/01_export_signer_level1.sh"
}

export_signer_level2() {
  run_cmd "Export Signer Level2" 0 "${SCRIPTS_DIR}/export/02_export_signer_level2.sh"
}

export_signer_level3_client() {
  run_cmd "Export Signer Level3 Client" 0 "${SCRIPTS_DIR}/export/03_export_signer_level3_client.sh"
}

export_signer_level3_server() {
  run_cmd "Export Signer Level3 Server" 0 "${SCRIPTS_DIR}/export/03_export_signer_level3_server.sh"
}

export_client() {
  local name alias password
  name="$(prompt "Client name")"
  alias="$(prompt "Alias (blank for default)")"
  password="$(prompt_secret "Password (blank to use P12_PASSWORD)")"
  if [[ -n "$password" ]]; then
    run_cmd "Export Client Bundle" 1 "${SCRIPTS_DIR}/export/04_export_client.sh" "$name" ${alias:+$alias} "$password"
  else
    run_cmd "Export Client Bundle" 1 "${SCRIPTS_DIR}/export/04_export_client.sh" "$name" ${alias:+$alias}
  fi
}

export_server() {
  local name alias password
  name="$(prompt "Server name")"
  alias="$(prompt "Alias (blank for default)")"
  password="$(prompt_secret "Password (blank to use P12_PASSWORD)")"
  if [[ -n "$password" ]]; then
    run_cmd "Export Server Bundle" 1 "${SCRIPTS_DIR}/export/04_export_server.sh" "$name" ${alias:+$alias} "$password"
  else
    run_cmd "Export Server Bundle" 1 "${SCRIPTS_DIR}/export/04_export_server.sh" "$name" ${alias:+$alias}
  fi
}

import_root() {
  local bundle
  bundle="$(prompt "Bundle dir (blank for default trust-bundles)")"
  run_cmd "Import Root" 0 "${SCRIPTS_DIR}/import/00_import_root.sh" ${bundle:+$bundle}
}

import_level1() {
  local bundle
  bundle="$(prompt "Bundle dir (blank for default trust-bundles)")"
  run_cmd "Import Level1" 0 "${SCRIPTS_DIR}/import/01_import_level1.sh" ${bundle:+$bundle}
}

import_level2() {
  local bundle
  bundle="$(prompt "Bundle dir (blank for default trust-bundles)")"
  run_cmd "Import Level2" 0 "${SCRIPTS_DIR}/import/02_import_level2.sh" ${bundle:+$bundle}
}

import_level3_client() {
  local bundle
  bundle="$(prompt "Bundle dir (blank for default trust-bundles)")"
  run_cmd "Import Level3 Client" 0 "${SCRIPTS_DIR}/import/03_import_level3_client.sh" ${bundle:+$bundle}
}

import_level3_server() {
  local bundle
  bundle="$(prompt "Bundle dir (blank for default trust-bundles)")"
  run_cmd "Import Level3 Server" 0 "${SCRIPTS_DIR}/import/03_import_level3_server.sh" ${bundle:+$bundle}
}

menu_make() {
  while true; do
    clear_screen
    print_header "PKI Admin - Make CAs"
    print_ca_status
    printf "\n"
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
    print_header "PKI Admin - Issue Certs"
    print_ca_status
    print_endpoint_status
    printf "\n"
    printf "1) Issue Client Cert\n"
    printf "2) Issue Client Cert from CSR\n"
    printf "3) Issue Server Cert\n"
    printf "4) Issue Server Cert from CSR\n"
    printf "5) Issue from USB (csr-list)\n"
    printf "0) Back\n"
    read -r -p "Select: " choice
    case "$choice" in
      1) issue_client; pause ;;
      2) issue_client_from_csr; pause ;;
      3) issue_server; pause ;;
      4) issue_server_from_csr; pause ;;
      5) issue_from_usb ;;
      0) return ;;
      *) printf "Invalid choice\n"; pause ;;
    esac
  done
}

menu_export() {
  while true; do
    clear_screen
    print_header "PKI Admin - Export Bundles"
    print_bundle_status
    printf "\n"
    printf "1) Export Root\n"
    printf "2) Export Signer Level1\n"
    printf "3) Export Signer Level2\n"
    printf "4) Export Signer Level3 Client\n"
    printf "5) Export Signer Level3 Server\n"
    printf "6) Export Client PKCS#12\n"
    printf "7) Export Server PKCS#12\n"
    printf "8) Verify PKCS#12 Password\n"
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
      8) verify_p12; pause ;;
      0) return ;;
      *) printf "Invalid choice\n"; pause ;;
    esac
  done
}

verify_p12() {
  local name password path
  name="$(prompt "Server name")"
  password="$(prompt_secret "Password")"
  path="trust-bundles/server/${name}/${name}.p12"
  if [[ ! -f "$path" ]]; then
    printf "Missing PKCS#12 file: %s\n" "$path"
    return
  fi
  if openssl pkcs12 -info -in "$path" -noout -passin "pass:${password}"; then
    printf "Password OK\n"
  else
    printf "Password invalid\n"
  fi
}

menu_import() {
  while true; do
    clear_screen
    print_header "PKI Admin - Import Bundles"
    print_bundle_status
    printf "\n"
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
    print_header "PKI Admin"
    print_ca_status
    print_endpoint_status
    print_bundle_status
    printf "\n"
    printf "1) Make CAs\n"
    printf "2) Issue Certs\n"
    printf "3) Export Bundles\n"
    printf "4) Import Bundles\n"
    printf "5) History\n"
    printf "0) Exit\n"
    read -r -p "Select: " choice
    case "$choice" in
      1) menu_make ;;
      2) menu_issue ;;
      3) menu_export ;;
      4) menu_import ;;
      5) menu_history ;;
      0) exit 0 ;;
      *) printf "Invalid choice\n"; pause ;;
    esac
  done
}

menu_history() {
  local lines entry selection action cmd label needs_password ts password
  local -a cmd_array
  local script_base
  local hist_arg
  hist_arg() {
    local idx="$1"
    local fallback="$2"
    if [[ ${cmd_array[$idx]+set} ]]; then
      printf '%s' "${cmd_array[$idx]}"
    else
      printf '%s' "$fallback"
    fi
  }
  while true; do
    clear_screen
    print_header "PKI Admin - History"
    if [[ ! -f "$HISTORY_FILE" ]]; then
      printf "No history yet.\n"
      pause
      return
    fi
    lines="$(tail -n 10 "$HISTORY_FILE")"
    printf "Last 10 commands:\n"
    printf "%s\n" "$lines" | nl -w2 -s') '
    printf "\nSelect entry number or 0 to back.\n"
    read -r -p "Select: " selection
    if [[ "$selection" == "0" ]]; then
      return
    fi
    entry="$(printf "%s\n" "$lines" | sed -n "${selection}p")"
    if [[ -z "$entry" ]]; then
      printf "Invalid selection\n"
      pause
      continue
    fi
    IFS='|' read -r ts label needs_password cmd <<< "$entry"
    printf "\n[%s] %s\n%s\n" "$ts" "$label" "$cmd"
    read -r -p "Action: (r)erun, (e)dit, (b)ack: " action
    case "$action" in
      r|R)
        cmd_array=()
        eval "cmd_array=($cmd)"
        if [[ "$needs_password" == "1" ]]; then
          password="$(prompt_secret "Password")"
          run_history_command "$label" "$needs_password" "$password" "${cmd_array[@]}"
        else
          run_history_command "$label" "$needs_password" "" "${cmd_array[@]}"
        fi
        pause
        ;;
      e|E)
        cmd_array=()
        eval "cmd_array=($cmd)"
        script_base="$(basename "${cmd_array[0]}")"
        case "$script_base" in
          00_make_root.sh)
            cmd_array[1]="$(prompt "Root CN" "$(hist_arg 1 "$(conf_get root_cn)")")"
            cmd_array[2]="$(prompt "Root days" "$(hist_arg 2 "$(conf_get root_days)")")"
            cmd_array[3]="$(prompt "Root key bits" "$(hist_arg 3 "$(conf_get root_key_bits)")")"
            ;;
          01_make_level1.sh)
            cmd_array[1]="$(prompt "Level1 CN" "$(hist_arg 1 "$(conf_get level1_cn)")")"
            cmd_array[2]="$(prompt "Level1 days" "$(hist_arg 2 "$(conf_get level1_days)")")"
            cmd_array[3]="$(prompt "Level1 key bits" "$(hist_arg 3 "$(conf_get level1_key_bits)")")"
            ;;
          02_make_level2.sh)
            cmd_array[1]="$(prompt "Level2 CN" "$(hist_arg 1 "$(conf_get level2_cn)")")"
            cmd_array[2]="$(prompt "Level2 days" "$(hist_arg 2 "$(conf_get level2_days)")")"
            cmd_array[3]="$(prompt "Level2 key bits" "$(hist_arg 3 "$(conf_get level2_key_bits)")")"
            ;;
          03_make_level3_client.sh)
            cmd_array[1]="$(prompt "Level3 Client CN" "$(hist_arg 1 "$(conf_get level3_client_cn)")")"
            cmd_array[2]="$(prompt "Level3 Client days" "$(hist_arg 2 "$(conf_get level3_client_days)")")"
            cmd_array[3]="$(prompt "Level3 Client key bits" "$(hist_arg 3 "$(conf_get level3_client_key_bits)")")"
            ;;
          03_make_level3_server.sh)
            cmd_array[1]="$(prompt "Level3 Server CN" "$(hist_arg 1 "$(conf_get level3_server_cn)")")"
            cmd_array[2]="$(prompt "Level3 Server days" "$(hist_arg 2 "$(conf_get level3_server_days)")")"
            cmd_array[3]="$(prompt "Level3 Server key bits" "$(hist_arg 3 "$(conf_get level3_server_key_bits)")")"
            ;;
          04_make_client.sh)
            cmd_array[1]="$(prompt "Client CN" "$(hist_arg 1 "$(conf_get client_cn)")")"
            cmd_array[2]="$(prompt "Client days" "$(hist_arg 2 "$(conf_get client_days)")")"
            cmd_array[3]="$(prompt "Client key bits" "$(hist_arg 3 "$(conf_get client_key_bits)")")"
            ;;
          04_make_client_from_csr.sh)
            cmd_array[1]="$(prompt "Client name" "$(hist_arg 1 "")")"
            cmd_array[2]="$(prompt "CSR path" "$(hist_arg 2 "")")"
            cmd_array[3]="$(prompt "Days" "$(hist_arg 3 "$(conf_get client_days)")")"
            ;;
          04_make_server.sh)
            cmd_array[1]="$(prompt "Server CN" "$(hist_arg 1 "")")"
            cmd_array[2]="$(prompt "Server SAN" "$(hist_arg 2 "$(conf_get server_san)")")"
            cmd_array[3]="$(prompt "Server days" "$(hist_arg 3 "$(conf_get server_days)")")"
            cmd_array[4]="$(prompt "Server key bits" "$(hist_arg 4 "$(conf_get server_key_bits)")")"
            ;;
          04_make_server_from_csr.sh)
            cmd_array[1]="$(prompt "Server name" "$(hist_arg 1 "")")"
            cmd_array[2]="$(prompt "CSR path" "$(hist_arg 2 "")")"
            cmd_array[3]="$(prompt "SAN" "$(hist_arg 3 "$(conf_get server_san)")")"
            cmd_array[4]="$(prompt "Days" "$(hist_arg 4 "$(conf_get server_days)")")"
            ;;
          04_export_client.sh)
            cmd_array[1]="$(prompt "Client name" "$(hist_arg 1 "")")"
            cmd_array[2]="$(prompt "Alias (blank for default)" "$(hist_arg 2 "")")"
            ;;
          04_export_server.sh)
            cmd_array[1]="$(prompt "Server name" "$(hist_arg 1 "")")"
            cmd_array[2]="$(prompt "Alias (blank for default)" "$(hist_arg 2 "")")"
            ;;
          00_import_root.sh|01_import_level1.sh|02_import_level2.sh|03_import_level3_client.sh|03_import_level3_server.sh)
            cmd_array[1]="$(prompt "Bundle dir (blank for default trust-bundles)" "$(hist_arg 1 "")")"
            ;;
          *)
            read -r -p "New command: " cmd
            if [[ -z "$cmd" ]]; then
              printf "No command provided\n"
              pause
              continue
            fi
            cmd_array=()
            eval "cmd_array=($cmd)"
            ;;
        esac
        if [[ "$needs_password" == "1" ]]; then
          password="$(prompt_secret "Password")"
          run_history_command "$label" "$needs_password" "$password" "${cmd_array[@]}"
        else
          run_history_command "$label" "$needs_password" "" "${cmd_array[@]}"
        fi
        pause
        ;;
      *) ;;
    esac
  done
}

main_menu
