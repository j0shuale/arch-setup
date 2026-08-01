#!/bin/bash
# Runs INSIDE arch-chroot (invoked automatically by pre-chroot-install.sh).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Log everything (stdout + stderr) to a timestamped file, while still showing it live.
mkdir -p "$SCRIPT_DIR/logs"
LOG_FILE="$SCRIPT_DIR/logs/post-chroot-install-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

source "$SCRIPT_DIR/vars.sh"

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


