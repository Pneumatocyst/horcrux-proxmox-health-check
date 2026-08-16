#!/usr/bin/env bash

# HORCRUX Proxmox Health Check
# A read-only health summary for standalone Proxmox VE hosts.
#
# Exit codes:
#   0 = healthy
#   1 = one or more warnings
#   2 = one or more critical findings
#  64 = invalid command-line usage

set -uo pipefail

readonly SCRIPT_VERSION="1.0.1"

ROOT_WARN=80
ROOT_CRIT=90
MEM_WARN=85
MEM_CRIT=95
LOAD_WARN=75
LOAD_CRIT=100
CURL_TIMEOUT=5
BRIDGE="vmbr0"
SERVICES_FILE=""
COLOR_DISABLED=0
declare -a REQUIRED_MOUNTS=()

OVERALL_STATUS=0
OK_COUNT=0
WARN_COUNT=0
CRIT_COUNT=0
INFO_COUNT=0
SKIP_COUNT=0

COLOR_RESET=""
COLOR_GREEN=""
COLOR_YELLOW=""
COLOR_RED=""
COLOR_BLUE=""
COLOR_GRAY=""

usage() {
  cat <<'EOF'
Usage: sudo ./proxmox-health-check.sh [options]

Read-only health summary for a Proxmox VE host.

Options:
  --root-warn PCT       Root filesystem warning threshold (default: 80)
  --root-crit PCT       Root filesystem critical threshold (default: 90)
  --mem-warn PCT        Memory warning threshold (default: 85)
  --mem-crit PCT        Memory critical threshold (default: 95)
  --load-warn PCT       Load/core warning threshold (default: 75)
  --load-crit PCT       Load/core critical threshold (default: 100)
  --bridge NAME         Expected Linux bridge (default: vmbr0)
  --mount PATH          Require PATH to be an active mount; repeatable
  --services FILE       Check HTTP endpoints listed in FILE
  --timeout SECONDS     HTTP connection and total timeout (default: 5)
  --no-color            Disable ANSI colors
  --version             Print version and exit
  -h, --help            Show this help

Services file format:
  Display Name|https://service.example.internal:8006|insecure

The optional third field may be "insecure" for a trusted internal service
using a self-signed certificate. Never place credentials or tokens in URLs.
EOF
}

die_usage() {
  printf 'Error: %s\n\n' "$1" >&2
  usage >&2
  exit 64
}

is_percent() {
  [[ "$1" =~ ^[0-9]+$ ]] && (( 10#$1 >= 0 && 10#$1 <= 100 ))
}

is_positive_integer() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

require_value() {
  (( $# >= 2 )) || die_usage "$1 requires a value"
}

while (( $# > 0 )); do
  case "$1" in
    --root-warn)
      require_value "$@"
      ROOT_WARN="$2"
      shift 2
      ;;
    --root-crit)
      require_value "$@"
      ROOT_CRIT="$2"
      shift 2
      ;;
    --mem-warn)
      require_value "$@"
      MEM_WARN="$2"
      shift 2
      ;;
    --mem-crit)
      require_value "$@"
      MEM_CRIT="$2"
      shift 2
      ;;
    --load-warn)
      require_value "$@"
      LOAD_WARN="$2"
      shift 2
      ;;
    --load-crit)
      require_value "$@"
      LOAD_CRIT="$2"
      shift 2
      ;;
    --bridge)
      require_value "$@"
      BRIDGE="$2"
      shift 2
      ;;
    --mount)
      require_value "$@"
      REQUIRED_MOUNTS+=("$2")
      shift 2
      ;;
    --services)
      require_value "$@"
      SERVICES_FILE="$2"
      shift 2
      ;;
    --timeout)
      require_value "$@"
      CURL_TIMEOUT="$2"
      shift 2
      ;;
    --no-color)
      COLOR_DISABLED=1
      shift
      ;;
    --version)
      printf 'HORCRUX Proxmox Health Check %s\n' "$SCRIPT_VERSION"
      exit 0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die_usage "unknown option: $1"
      ;;
  esac
done

for threshold in "$ROOT_WARN" "$ROOT_CRIT" "$MEM_WARN" "$MEM_CRIT" "$LOAD_WARN" "$LOAD_CRIT"; do
  is_percent "$threshold" || die_usage "thresholds must be whole numbers from 0 to 100"
done
ROOT_WARN=$(( 10#$ROOT_WARN ))
ROOT_CRIT=$(( 10#$ROOT_CRIT ))
MEM_WARN=$(( 10#$MEM_WARN ))
MEM_CRIT=$(( 10#$MEM_CRIT ))
LOAD_WARN=$(( 10#$LOAD_WARN ))
LOAD_CRIT=$(( 10#$LOAD_CRIT ))
(( ROOT_WARN < ROOT_CRIT )) || die_usage "--root-warn must be lower than --root-crit"
(( MEM_WARN < MEM_CRIT )) || die_usage "--mem-warn must be lower than --mem-crit"
(( LOAD_WARN < LOAD_CRIT )) || die_usage "--load-warn must be lower than --load-crit"
is_positive_integer "$CURL_TIMEOUT" || die_usage "--timeout must be a positive whole number"

init_colors() {
  if (( COLOR_DISABLED == 0 )) && [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
    COLOR_RESET=$'\033[0m'
    COLOR_GREEN=$'\033[32m'
    COLOR_YELLOW=$'\033[33m'
    COLOR_RED=$'\033[31m'
    COLOR_BLUE=$'\033[34m'
    COLOR_GRAY=$'\033[90m'
  fi
}

section() {
  printf '\n%b%s%b\n' "$COLOR_BLUE" "$1" "$COLOR_RESET"
  printf '%s\n' "$(printf '%*s' "${#1}" '' | tr ' ' '-')"
}

record() {
  local level="$1"
  local label="$2"
  local detail="$3"
  local color="$COLOR_GRAY"

  case "$level" in
    OK)
      color="$COLOR_GREEN"
      (( OK_COUNT += 1 ))
      ;;
    WARN)
      color="$COLOR_YELLOW"
      (( WARN_COUNT += 1 ))
      (( OVERALL_STATUS < 1 )) && OVERALL_STATUS=1
      ;;
    CRIT)
      color="$COLOR_RED"
      (( CRIT_COUNT += 1 ))
      OVERALL_STATUS=2
      ;;
    INFO)
      color="$COLOR_BLUE"
      (( INFO_COUNT += 1 ))
      ;;
    SKIP)
      color="$COLOR_GRAY"
      (( SKIP_COUNT += 1 ))
      ;;
  esac

  printf '  %b[%-4s]%b %-24s %s\n' "$color" "$level" "$COLOR_RESET" "$label" "$detail"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

human_bytes() {
  local bytes="${1:-0}"
  if command_exists numfmt; then
    numfmt --to=iec-i --suffix=B "$bytes" 2>/dev/null || printf '%s B' "$bytes"
  else
    awk -v bytes="$bytes" 'BEGIN {
      split("B KiB MiB GiB TiB", unit, " "); i=1;
      while (bytes >= 1024 && i < 5) { bytes /= 1024; i++ }
      printf "%.1f %s", bytes, unit[i]
    }'
  fi
}

level_for_percent() {
  local value="$1"
  local warn="$2"
  local crit="$3"
  if (( value >= crit )); then
    printf 'CRIT'
  elif (( value >= warn )); then
    printf 'WARN'
  else
    printf 'OK'
  fi
}

print_header() {
  local host_name="unknown"
  local report_time
  host_name="$(hostname -f 2>/dev/null || hostname 2>/dev/null || printf 'unknown')"
  report_time="$(date --iso-8601=seconds 2>/dev/null || date)"

  printf '%bHORCRUX Proxmox Health Check%b  v%s\n' "$COLOR_BLUE" "$COLOR_RESET" "$SCRIPT_VERSION"
  printf 'Host: %s\n' "$host_name"
  printf 'Time: %s\n' "$report_time"
  printf 'Mode: read-only\n'
}

check_platform() {
  section "Platform"

  if command_exists pveversion; then
    local pve_version
    pve_version="$(pveversion 2>/dev/null | head -n 1)"
    if [[ -n "$pve_version" ]]; then
      record OK "Proxmox VE" "$pve_version"
    else
      record WARN "Proxmox VE" "pveversion returned no data"
    fi
  else
    record WARN "Proxmox VE" "pveversion not found; running limited checks"
  fi

  record INFO "Kernel" "$(uname -r)"

  local uptime_text="unavailable"
  if uptime -p >/dev/null 2>&1; then
    uptime_text="$(uptime -p)"
  fi
  record INFO "Uptime" "$uptime_text"

  local cpu_model="unknown"
  cpu_model="$(awk -F: '/model name/ { sub(/^[[:space:]]+/, "", $2); print $2; exit }' /proc/cpuinfo 2>/dev/null)"
  record INFO "CPU" "${cpu_model:-unknown}"
}

check_cpu_load() {
  section "CPU and Memory"

  local cores=1
  local load1="0"
  local load_pct=0
  local load_level

  if command_exists nproc; then
    cores="$(nproc 2>/dev/null || printf '1')"
  elif command_exists getconf; then
    cores="$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '1')"
  fi
  [[ "$cores" =~ ^[1-9][0-9]*$ ]] || cores=1

  read -r load1 _ < /proc/loadavg
  load_pct="$(awk -v load="$load1" -v cores="$cores" 'BEGIN { printf "%.0f", (load / cores) * 100 }')"
  load_level="$(level_for_percent "$load_pct" "$LOAD_WARN" "$LOAD_CRIT")"
  record "$load_level" "Load average" "${load1} across ${cores} cores (${load_pct}% of core capacity)"

  local total_kb=0
  local available_kb=0
  local used_kb=0
  local used_pct=0
  local memory_level

  total_kb="$(awk '/^MemTotal:/ { print $2 }' /proc/meminfo 2>/dev/null)"
  available_kb="$(awk '/^MemAvailable:/ { print $2 }' /proc/meminfo 2>/dev/null)"

  if [[ "$total_kb" =~ ^[0-9]+$ ]] && [[ "$available_kb" =~ ^[0-9]+$ ]] && (( total_kb > 0 )); then
    used_kb=$(( total_kb - available_kb ))
    used_pct=$(( used_kb * 100 / total_kb ))
    memory_level="$(level_for_percent "$used_pct" "$MEM_WARN" "$MEM_CRIT")"
    record "$memory_level" "Memory" "$(human_bytes "$(( used_kb * 1024 ))") / $(human_bytes "$(( total_kb * 1024 ))") used (${used_pct}%)"
  else
    record SKIP "Memory" "could not read /proc/meminfo"
  fi
}

check_root_disk() {
  section "Root Filesystem"

  local total=""
  local used=""
  local available=""
  local used_pct=""
  local disk_level

  read -r total used available used_pct < <(
    df -P -B1 / 2>/dev/null | awk 'NR == 2 { gsub(/%/, "", $5); print $2, $3, $4, $5 }'
  )

  if [[ "$used_pct" =~ ^[0-9]+$ ]]; then
    disk_level="$(level_for_percent "$used_pct" "$ROOT_WARN" "$ROOT_CRIT")"
    record "$disk_level" "Root disk" "$(human_bytes "$used") / $(human_bytes "$total") used (${used_pct}%); $(human_bytes "$available") free"
  else
    record CRIT "Root disk" "unable to read filesystem usage"
  fi
}

check_required_mounts() {
  section "Required Mounts"

  if (( ${#REQUIRED_MOUNTS[@]} == 0 )); then
    record SKIP "Mount checks" "none requested; add --mount /path"
    return
  fi

  if ! command_exists mountpoint; then
    record SKIP "Mount checks" "mountpoint command not available"
    return
  fi

  local mount_path
  for mount_path in "${REQUIRED_MOUNTS[@]}"; do
    if mountpoint -q -- "$mount_path"; then
      local source="unknown"
      local filesystem="unknown"
      if command_exists findmnt; then
        source="$(findmnt -rn -M "$mount_path" -o SOURCE 2>/dev/null || printf 'unknown')"
        filesystem="$(findmnt -rn -M "$mount_path" -o FSTYPE 2>/dev/null || printf 'unknown')"
      fi
      record OK "$mount_path" "mounted from ${source:-unknown} (${filesystem:-unknown})"
    else
      record CRIT "$mount_path" "not mounted"
    fi
  done
}

check_bridge() {
  section "Network"

  if ! command_exists ip; then
    record SKIP "Linux bridge" "ip command not available"
    return
  fi

  if ip link show "$BRIDGE" >/dev/null 2>&1; then
    local state
    state="$(ip -br link show "$BRIDGE" 2>/dev/null | awk '{ print $2 }')"
    if [[ "$state" == "UP" ]]; then
      record OK "Bridge $BRIDGE" "UP"
    else
      record CRIT "Bridge $BRIDGE" "state=${state:-unknown}"
    fi
  else
    record CRIT "Bridge $BRIDGE" "not found"
  fi
}

check_failed_units() {
  section "System Services"

  if ! command_exists systemctl; then
    record SKIP "Failed units" "systemctl not available"
    return
  fi
  if [[ ! -d /run/systemd/system ]]; then
    record SKIP "Failed units" "systemd is not running"
    return
  fi

  local failed_units
  local systemctl_status=0
  failed_units="$(systemctl --failed --no-legend --plain 2>/dev/null)" || systemctl_status=$?
  if (( systemctl_status != 0 )); then
    record SKIP "Failed units" "systemd is unavailable or inaccessible"
    return
  fi
  if [[ -z "$failed_units" ]]; then
    record OK "Failed units" "none"
  else
    local failed_count
    failed_count="$(printf '%s\n' "$failed_units" | sed '/^[[:space:]]*$/d' | wc -l)"
    record WARN "Failed units" "${failed_count} unit(s)"
    printf '%s\n' "$failed_units" | sed -n '1,5p' | sed 's/^/      /'
  fi
}

check_pve_storage() {
  section "Proxmox Storage"

  if ! command_exists pvesm; then
    record SKIP "PVE storage" "pvesm not available"
    return
  fi

  local storage_output
  storage_output="$(pvesm status 2>/dev/null || true)"
  if [[ -z "$storage_output" ]]; then
    record WARN "PVE storage" "unable to retrieve status"
    return
  fi

  local found=0
  while read -r name type status total used available percent _; do
    [[ "$name" == "Name" ]] && continue
    [[ -z "$name" ]] && continue
    found=1

    if [[ "$status" != "active" ]]; then
      record CRIT "$name" "type=$type status=$status"
      continue
    fi

    local pct_number="${percent%%%}"
    pct_number="${pct_number%%.*}"
    if [[ "$pct_number" =~ ^[0-9]+$ ]]; then
      local storage_level
      storage_level="$(level_for_percent "$pct_number" "$ROOT_WARN" "$ROOT_CRIT")"
      record "$storage_level" "$name" "active, ${percent} used; $(human_bytes "$(( available * 1024 ))") free"
    else
      record OK "$name" "active"
    fi
  done <<< "$storage_output"

  (( found == 1 )) || record INFO "PVE storage" "no configured storage returned"
}

print_guest_table_header() {
  printf '      %-7s %-26s %-12s %-8s\n' "ID" "NAME" "STATUS" "ONBOOT"
}

check_qemu_guests() {
  section "QEMU Virtual Machines"

  if ! command_exists qm; then
    record SKIP "QEMU guests" "qm not available"
    return
  fi

  local guest_output
  local qm_status=0
  guest_output="$(qm list 2>/dev/null)" || qm_status=$?
  if (( qm_status != 0 )); then
    record WARN "QEMU guests" "unable to retrieve VM list"
    return
  fi
  if [[ -z "$guest_output" ]]; then
    record INFO "QEMU guests" "none configured"
    return
  fi

  local total=0
  local running=0
  local vmid name status onboot
  print_guest_table_header
  while read -r vmid name status _; do
    [[ "$vmid" == "VMID" ]] && continue
    [[ "$vmid" =~ ^[0-9]+$ ]] || continue
    (( total += 1 ))
    [[ "$status" == "running" ]] && (( running += 1 ))
    onboot="$(qm config "$vmid" 2>/dev/null | awk -F: '/^onboot:/ { gsub(/[[:space:]]/, "", $2); print $2; exit }')"
    [[ -n "$onboot" ]] || onboot="0"
    printf '      %-7s %-26s %-12s %-8s\n' "$vmid" "$name" "$status" "$onboot"
    if [[ "$onboot" == "1" && "$status" != "running" ]]; then
      record WARN "VM $vmid" "configured for autostart but currently $status"
    fi
  done <<< "$guest_output"

  if (( total == 0 )); then
    record INFO "QEMU guests" "none configured"
  else
    record INFO "QEMU summary" "${running}/${total} running"
  fi
}

check_lxc_guests() {
  section "LXC Containers"

  if ! command_exists pct; then
    record SKIP "LXC containers" "pct not available"
    return
  fi

  local guest_output
  local pct_status=0
  guest_output="$(pct list 2>/dev/null)" || pct_status=$?
  if (( pct_status != 0 )); then
    record WARN "LXC containers" "unable to retrieve container list"
    return
  fi
  if [[ -z "$guest_output" ]]; then
    record INFO "LXC containers" "none configured"
    return
  fi

  local total=0
  local running=0
  local vmid status remainder name onboot
  print_guest_table_header
  while read -r vmid status remainder; do
    [[ "$vmid" == "VMID" ]] && continue
    [[ "$vmid" =~ ^[0-9]+$ ]] || continue
    name="${remainder##* }"
    (( total += 1 ))
    [[ "$status" == "running" ]] && (( running += 1 ))
    onboot="$(pct config "$vmid" 2>/dev/null | awk -F: '/^onboot:/ { gsub(/[[:space:]]/, "", $2); print $2; exit }')"
    [[ -n "$onboot" ]] || onboot="0"
    printf '      %-7s %-26s %-12s %-8s\n' "$vmid" "${name:--}" "$status" "$onboot"
    if [[ "$onboot" == "1" && "$status" != "running" ]]; then
      record WARN "CT $vmid" "configured for autostart but currently $status"
    fi
  done <<< "$guest_output"

  if (( total == 0 )); then
    record INFO "LXC containers" "none configured"
  else
    record INFO "LXC summary" "${running}/${total} running"
  fi
}

check_http_services() {
  section "HTTP Services"

  if [[ -z "$SERVICES_FILE" ]]; then
    record SKIP "Endpoint checks" "none requested; add --services FILE"
    return
  fi
  if [[ ! -r "$SERVICES_FILE" ]]; then
    record CRIT "Endpoint checks" "cannot read $SERVICES_FILE"
    return
  fi
  if ! command_exists curl; then
    record SKIP "Endpoint checks" "curl not available"
    return
  fi

  local found=0
  local raw_name raw_url raw_tls extra
  while IFS='|' read -r raw_name raw_url raw_tls extra; do
    local name url tls_mode
    name="$(trim "${raw_name:-}")"
    url="$(trim "${raw_url:-}")"
    tls_mode="$(trim "${raw_tls:-}")"

    [[ -z "$name" || "$name" == \#* ]] && continue
    found=1
    if [[ -z "$url" || -n "${extra:-}" ]]; then
      record CRIT "$name" "invalid services-file entry"
      continue
    fi

    local -a curl_args=(
      --silent
      --show-error
      --output /dev/null
      --location
      --max-redirs 3
      --connect-timeout "$CURL_TIMEOUT"
      --max-time "$CURL_TIMEOUT"
      --write-out '%{http_code}|%{time_total}'
    )
    [[ "$tls_mode" == "insecure" ]] && curl_args+=(--insecure)

    local response=""
    local curl_status=0
    response="$(curl "${curl_args[@]}" -- "$url" 2>/dev/null)" || curl_status=$?
    if (( curl_status != 0 )); then
      record CRIT "$name" "unreachable (curl exit $curl_status)"
      continue
    fi

    local http_code="${response%%|*}"
    local elapsed="${response#*|}"
    local elapsed_ms
    elapsed_ms="$(awk -v seconds="$elapsed" 'BEGIN { printf "%.0f", seconds * 1000 }')"

    if [[ "$http_code" =~ ^[23][0-9][0-9]$ ]]; then
      record OK "$name" "HTTP $http_code in ${elapsed_ms} ms"
    else
      record CRIT "$name" "HTTP ${http_code:-unknown} in ${elapsed_ms} ms"
    fi
  done < "$SERVICES_FILE"

  (( found == 1 )) || record INFO "Endpoint checks" "services file contained no entries"
}

print_summary() {
  section "Summary"
  printf '  OK=%d  WARN=%d  CRIT=%d  INFO=%d  SKIP=%d\n' \
    "$OK_COUNT" "$WARN_COUNT" "$CRIT_COUNT" "$INFO_COUNT" "$SKIP_COUNT"

  case "$OVERALL_STATUS" in
    0) record OK "Overall" "healthy" ;;
    1) record WARN "Overall" "review warnings" ;;
    2) record CRIT "Overall" "action required" ;;
  esac
}

init_colors
print_header
check_platform
check_cpu_load
check_root_disk
check_required_mounts
check_bridge
check_failed_units
check_pve_storage
check_qemu_guests
check_lxc_guests
check_http_services
print_summary

exit "$OVERALL_STATUS"
