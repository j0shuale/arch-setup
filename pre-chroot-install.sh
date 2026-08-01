#!/bin/bash
# Run this FIRST, from the live Arch ISO (as root).
# It partitions/formats the drive, installs the base system, then
# chains directly into post-chroot-install.sh inside arch-chroot.

set -euo pipefail

# Resolve repo dir so this works regardless of cwd.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/vars.sh"

# set dvorak and big-up font
loadkeys $KEYMAP
setfont ter-132b

# if the following is 64, it's 64 bit UEFI
# 32 = UEFI mode 32 bit, but limited
# No such file or directory = BIOS mode
cat /sys/firmware/efi/fw_platform_size

# ensure enp... interface is up
# make sure wireless card is not blocked with rfkill
ip link
rfkill


# connect to internet

if [[ -z "${WIFI_SSID:-}" ]]; then
	read -rsp "Wifi SSID: " WIFI_SSID
	echo
fi
if [[ -z "${WIFI_PASSPHRASE:-}" ]]; then
	read -rsp "Wifi passphrase for '$WIFI_SSID': " WIFI_PASSPHRASE
	echo
fi
iwctl --passphrase "$WIFI_PASSPHRASE" station wlan0 connect "$WIFI_SSID"
timedatectl

# partitioning
echo "Partitioning $DRIVE... (this WIPES the drive)"

# Remove any leftover filesystem/partition-table signatures from a previous
# install. Without this, fdisk stops to ask "remove the ext4/swap signature?"
# for each old partition, which desyncs the heredoc below and breaks it.
wipefs --all --force "$DRIVE"

fdisk "$DRIVE" <<EOF
g
n


+1G
t
1
n


+$SWAPSIZE
t
19
n



w
EOF
# for the previous, it is partitioning the specific drive (could be different)
# it uses fdisk, creates a new GPT table, then a 1G EFI system partition
# then a 16GB (should change this to however much RAM you have for hibernation) partition of type Linux swap (double check 19 is the correct number)
# then a Linux filesystem partition of the rest.

# format
mkfs.ext4 "$P3"
mkswap "$P2"
mkfs.fat -F 32 "$P1"
# mount
mount "$P3" /mnt
mount --mkdir "$P1" /mnt/boot
swapon "$P2"


# installation
# semi minimal install. just need vim for config, network for wifi, and intel-ucode is security
pacstrap -K /mnt base linux linux-firmware vim networkmanager intel-ucode

# genfstab
genfstab -U /mnt >> /mnt/etc/fstab

# Harden the EFI partition mount: only root can read /boot.
sed -i '/\/boot/ s/fmask=0022/fmask=0077/; /\/boot/ s/dmask=0022/dmask=0077/' /mnt/etc/fstab

# Copy the repo into the new system so post-chroot + first-boot scripts are available.
mkdir -p /mnt/root/arch-setup
cp -r "$SCRIPT_DIR/." /mnt/root/arch-setup/

# Chain straight into the chroot phase — no manual arch-chroot needed.
arch-chroot -S /mnt /root/arch-setup/post-chroot-install.sh

echo
echo "Base install + chroot config complete."
echo "Now: reboot, remove the ISO, log in, then run: /root/arch-setup/install.sh"