#!/bin/bash
# shellcheck disable=SC2153  # config vars (DRIVE, HOSTNAME, etc.) come from sourced config.sh
# Phase 2: Locale, bootloader, user setup
# Run inside arch-chroot after Phase 1.
# Usage: arch-chroot /mnt /root/arch-setup/02-chroot.sh

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

check_root
load_config

log_info "=== Phase 2: Chroot setup ==="

# ---------------------------------------------------------------------------
# Timezone
# ---------------------------------------------------------------------------
log_info "Setting timezone to ${TIMEZONE}..."
dry_run_exec ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
dry_run_exec hwclock --systohc

# ---------------------------------------------------------------------------
# Locale
# ---------------------------------------------------------------------------
log_info "Configuring locale ${LOCALE}..."
dry_run_exec sed -i "s/^#${LOCALE} UTF-8/${LOCALE} UTF-8/" /etc/locale.gen
dry_run_exec locale-gen
dry_run_exec bash -c "echo 'LANG=${LOCALE}' > /etc/locale.conf"

# ---------------------------------------------------------------------------
# Console keymap
# ---------------------------------------------------------------------------
dry_run_exec bash -c "echo 'KEYMAP=${KEYMAP}' > /etc/vconsole.conf"

# ---------------------------------------------------------------------------
# Hostname
# ---------------------------------------------------------------------------
dry_run_exec bash -c "echo '${HOSTNAME}' > /etc/hostname"

# ---------------------------------------------------------------------------
# mkinitcpio — add resume hook for hibernation support
# ---------------------------------------------------------------------------
log_info "Adding 'resume' hook to mkinitcpio for hibernation..."
if ! grep -qw 'resume' /etc/mkinitcpio.conf; then
    dry_run_exec sed -i 's/\bfilesystems\b/filesystems resume/' /etc/mkinitcpio.conf
else
    log_info "  'resume' hook already present, skipping."
fi
dry_run_exec mkinitcpio -P

# ---------------------------------------------------------------------------
# Bootloader (systemd-boot)
# ---------------------------------------------------------------------------
log_info "Installing systemd-boot..."
dry_run_exec bootctl install

ROOT_PART="$(partition_name "${DRIVE}" 3)"
SWAP_PART="$(partition_name "${DRIVE}" 2)"
ROOT_UUID="$(blkid -s UUID -o value "${ROOT_PART}")"
SWAP_UUID="$(blkid -s UUID -o value "${SWAP_PART}")"

# Determine correct ucode initrd line from profiles
UCODE_INITRD=""
if [[ " ${PROFILES} " =~ " intel-laptop " ]]; then
    UCODE_INITRD="initrd /intel-ucode.img"
elif [[ " ${PROFILES} " =~ " amd-nvidia-desktop " ]]; then
    UCODE_INITRD="initrd /amd-ucode.img"
fi

log_info "Root UUID: ${ROOT_UUID}"
log_info "Swap UUID: ${SWAP_UUID} (resume)"

if [[ "${DRY_RUN:-0}" == "1" ]]; then
    echo "[DRY RUN] write /boot/loader/loader.conf"
    echo "[DRY RUN] write /boot/loader/entries/arch.conf (ucode: ${UCODE_INITRD:-none})"
else
    cat > /boot/loader/loader.conf <<'LOADEREOF'
default arch.conf
timeout 4
console-mode max
editor no
LOADEREOF

    # Build the boot entry; ucode line is optional
    {
        echo "title   Arch Linux"
        echo "linux   /vmlinuz-linux"
        [[ -n "${UCODE_INITRD}" ]] && echo "${UCODE_INITRD}"
        echo "initrd  /initramfs-linux.img"
        echo "options root=UUID=${ROOT_UUID} resume=UUID=${SWAP_UUID} rw"
    } > /boot/loader/entries/arch.conf
fi

# ---------------------------------------------------------------------------
# Root password
# ---------------------------------------------------------------------------
log_info "Set the root password:"
dry_run_exec passwd

# ---------------------------------------------------------------------------
# User account
# ---------------------------------------------------------------------------
log_info "Creating user '${USERNAME}'..."
dry_run_exec useradd -m -G wheel "${USERNAME}"
log_info "Set password for '${USERNAME}':"
dry_run_exec passwd "${USERNAME}"

# ---------------------------------------------------------------------------
# Sudoers
# ---------------------------------------------------------------------------
log_info "Configuring sudoers..."
dry_run_exec bash -c "echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel"
dry_run_exec bash -c "echo 'Defaults pwfeedback' > /etc/sudoers.d/10-pwfeedback"
dry_run_exec visudo -c

# Lock root login
dry_run_exec passwd -l root

log_info "=== Phase 2 complete ==="
log_info "Exit chroot, unmount, and reboot:"
log_info "  exit"
log_info "  umount -R /mnt"
log_info "  reboot"
log_info "After reboot log in as root, then run: /root/arch-setup/03-post-reboot.sh"
