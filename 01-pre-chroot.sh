#!/bin/bash
# shellcheck disable=SC2153  # config vars (DRIVE, HOSTNAME, etc.) come from sourced config.sh
# Phase 1: Partition, format, pacstrap
# Run from the Arch Linux live ISO as root.
# Usage: ./01-pre-chroot.sh

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/packages.sh
source "${SCRIPT_DIR}/lib/packages.sh"

check_root
load_config

log_info "=== Phase 1: Pre-chroot ==="
log_info "Drive:    ${DRIVE}"
log_info "EFI:      ${EFI_SIZE}  Swap: ${SWAP_SIZE}"
log_info "Hostname: ${HOSTNAME}"
log_info "Profiles: ${PROFILES}"
echo

# Confirm before destructive operations
confirm_step "WARNING: This will WIPE all data on ${DRIVE}. Proceed?" \
    || { log_info "Aborted."; exit 0; }

# ---------------------------------------------------------------------------
# Keyboard & font
# ---------------------------------------------------------------------------
log_info "Setting keymap to '${KEYMAP}' and console font..."
dry_run_exec loadkeys "${KEYMAP}"
dry_run_exec setfont ter-132b

# ---------------------------------------------------------------------------
# WiFi (optional; skip if already connected via ethernet)
# ---------------------------------------------------------------------------
log_info "Checking network connectivity..."
if ! ping -c1 -W2 archlinux.org &>/dev/null; then
    read -r -p "WiFi SSID (leave blank to skip): " WIFI_SSID
    if [[ -n "${WIFI_SSID}" ]]; then
        read -r -s -p "WiFi password: " WIFI_PASS
        echo
        dry_run_exec iwctl --passphrase "${WIFI_PASS}" station wlan0 connect "${WIFI_SSID}"
        unset WIFI_PASS
    fi
else
    log_info "Already connected to network."
fi

dry_run_exec timedatectl set-ntp true

# ---------------------------------------------------------------------------
# Verify UEFI mode
# ---------------------------------------------------------------------------
if [[ ! -f /sys/firmware/efi/fw_platform_size ]]; then
    log_error "Not booted in UEFI mode. This script requires UEFI."
    exit 1
fi

# ---------------------------------------------------------------------------
# Partition
# ---------------------------------------------------------------------------
EFI_PART="$(partition_name "${DRIVE}" 1)"
SWAP_PART="$(partition_name "${DRIVE}" 2)"
ROOT_PART="$(partition_name "${DRIVE}" 3)"

log_info "Partitioning ${DRIVE}..."
log_info "  ${EFI_PART}  → EFI System   (${EFI_SIZE})"
log_info "  ${SWAP_PART}  → Linux swap   (${SWAP_SIZE})"
log_info "  ${ROOT_PART}  → Linux root   (remainder)"

if [[ "${DRY_RUN:-0}" == "1" ]]; then
    echo "[DRY RUN] fdisk ${DRIVE} <<EOF ... g n +${EFI_SIZE} t 1 n +${SWAP_SIZE} t 19 n w EOF"
else
    fdisk "${DRIVE}" <<EOF
g
n


+${EFI_SIZE}
t
1
n


+${SWAP_SIZE}
t
19
n



w
EOF
fi

# ---------------------------------------------------------------------------
# Format
# ---------------------------------------------------------------------------
log_info "Formatting partitions..."
dry_run_exec mkfs.fat -F 32 "${EFI_PART}"
dry_run_exec mkswap "${SWAP_PART}"
dry_run_exec mkfs.ext4 "${ROOT_PART}"

# ---------------------------------------------------------------------------
# Mount
# ---------------------------------------------------------------------------
log_info "Mounting filesystems..."
dry_run_exec mount "${ROOT_PART}" /mnt
dry_run_exec mount --mkdir "${EFI_PART}" /mnt/boot
dry_run_exec swapon "${SWAP_PART}"

# ---------------------------------------------------------------------------
# Pacstrap
# ---------------------------------------------------------------------------
log_info "Building package list from profiles: ${PROFILES}"
PACKAGES="$(build_package_list)"
log_info "Packages: ${PACKAGES}"

# shellcheck disable=SC2086
dry_run_exec pacstrap -K /mnt ${PACKAGES}

# ---------------------------------------------------------------------------
# Fstab
# ---------------------------------------------------------------------------
log_info "Generating /etc/fstab..."
dry_run_exec bash -c "genfstab -U /mnt >> /mnt/etc/fstab"

# Apply fmask/dmask 0077 to the EFI partition entry for security
log_info "Hardening EFI fstab entry (fmask/dmask 0077)..."
dry_run_exec sed -i 's/fmask=0022,dmask=0022/fmask=0077,dmask=0077/g' /mnt/etc/fstab

# ---------------------------------------------------------------------------
# Copy scripts into new root for Phase 2
# ---------------------------------------------------------------------------
log_info "Copying install scripts to /mnt/root/arch-setup..."
dry_run_exec mkdir -p /mnt/root/arch-setup
dry_run_exec cp -r "${SCRIPT_DIR}/." /mnt/root/arch-setup/

log_info "=== Phase 1 complete ==="
log_info "Next: arch-chroot /mnt /root/arch-setup/02-chroot.sh"
