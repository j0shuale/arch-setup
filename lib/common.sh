#!/bin/bash
# lib/common.sh — Shared utilities for all install phases
# Source this file; do not execute directly.

# ---------------------------------------------------------------------------
# Colours
# ---------------------------------------------------------------------------
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ---------------------------------------------------------------------------
# Privilege check
# ---------------------------------------------------------------------------
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root."
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# User confirmation
# confirm_step "Are you sure?" — returns 0 (yes) or 1 (no)
# ---------------------------------------------------------------------------
confirm_step() {
    local msg="${1:-Continue?}"
    local response
    read -r -p "${BOLD}${msg}${NC} [y/N] " response
    [[ "${response,,}" == "y" ]]
}

# ---------------------------------------------------------------------------
# Config loader — sources config.sh and validates required variables
# ---------------------------------------------------------------------------
load_config() {
    local script_dir
    script_dir="$(dirname "$(readlink -f "$0")")"
    local config_file="${script_dir}/config.sh"

    if [[ ! -f "$config_file" ]]; then
        log_error "config.sh not found at: ${config_file}"
        log_error "Copy config.sh.example to config.sh and fill in your values."
        exit 1
    fi

    # shellcheck source=/dev/null
    source "$config_file"

    local required=(DRIVE HOSTNAME USERNAME TIMEZONE LOCALE KEYMAP SWAP_SIZE EFI_SIZE PROFILES GIT_NAME GIT_EMAIL)
    local missing=()
    for var in "${required[@]}"; do
        [[ -z "${!var:-}" ]] && missing+=("$var")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required config variables: ${missing[*]}"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Partition name helper
# partition_name DRIVE INDEX → partition path
#   /dev/nvme0n1  2 → /dev/nvme0n1p2
#   /dev/sda      2 → /dev/sda2
# ---------------------------------------------------------------------------
partition_name() {
    local drive="$1"
    local idx="$2"
    if [[ "$drive" =~ nvme|mmcblk ]]; then
        echo "${drive}p${idx}"
    else
        echo "${drive}${idx}"
    fi
}

# ---------------------------------------------------------------------------
# DRY_RUN wrapper
# Set DRY_RUN=1 to print commands instead of running them.
# ---------------------------------------------------------------------------
dry_run_exec() {
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
        echo "[DRY RUN] $*"
    else
        "$@"
    fi
}
