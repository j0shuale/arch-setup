#!/bin/bash
# Runs INSIDE arch-chroot (invoked automatically by pre-chroot-install.sh).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Log everything (stdout + stderr) to a timestamped file, while still showing it live.
mkdir -p "$SCRIPT_DIR/logs"
LOG_FILE="$SCRIPT_DIR/logs/post-chroot-install-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

source "$SCRIPT_DIR/vars.sh"

# Boot mode detected by pre-chroot-install.sh (uefi/bios). Fall back to probing
# /sys in case this script is ever run standalone.
if [[ -r "$SCRIPT_DIR/boot-mode.env" ]]; then
	source "$SCRIPT_DIR/boot-mode.env"
fi
BOOT_MODE="${BOOT_MODE:-$([[ -d /sys/firmware/efi ]] && echo uefi || echo bios)}"

ROOT_PART="$P3"

# random locale/time stuff
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime

hwclock --systohc

sed -i "s/^#${LOCALE} UTF-8/${LOCALE} UTF-8/" /etc/locale.gen

locale-gen

echo "LANG=$LOCALE" > /etc/locale.conf

echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

echo "$HOSTNAME" > /etc/hostname

# Set the root password.
echo "Set the root password:"
passwd

# The EFI mount is already hardened in fstab by pre-chroot (fmask/dmask 0077).
mkinitcpio -P

if [[ "$BOOT_MODE" == "uefi" ]]; then
	# systemd-boot on the ESP mounted at /boot.
	bootctl install
	UUID=$(lsblk -dno UUID "$ROOT_PART")
	cat <<EOF > /boot/loader/loader.conf
default arch.conf
timeout 4
console-mode max
editor no
EOF

	cat <<EOF > /boot/loader/entries/arch.conf
title Arch Linux
linux /vmlinuz-linux
initrd /intel-ucode.img
initrd /initramfs-linux.img
options root=UUID=$UUID rw
EOF
else
	# BIOS/legacy: GRUB embedded into the BIOS boot partition on $DRIVE.
	# grub-mkconfig auto-detects intel-ucode and the root UUID.
	grub-install --target=i386-pc "$DRIVE"
	grub-mkconfig -o /boot/grub/grub.cfg
fi


