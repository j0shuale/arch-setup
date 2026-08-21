#!/bin/bash
# Run this FIRST, from the live Arch ISO (as root).
# It partitions/formats the drive, installs the base system, then
# chains directly into post-chroot-install.sh inside arch-chroot.

set -euo pipefail

# Resolve repo dir so this works regardless of cwd.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Log everything (stdout + stderr) to a timestamped file, while still showing it live.
mkdir -p "$SCRIPT_DIR/logs"
LOG_FILE="$SCRIPT_DIR/logs/pre-chroot-install-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

source "$SCRIPT_DIR/vars.sh"

# set dvorak and big-up font
loadkeys $KEYMAP
setfont ter-132b

# Detect firmware/boot mode so the rest of the script can adapt.
# 64  = 64-bit UEFI
# 32  = 32-bit UEFI (limited)
# missing file = BIOS/legacy mode
if [[ -r /sys/firmware/efi/fw_platform_size ]]; then
	BOOT_MODE="uefi"
	echo "Boot mode: UEFI ($(cat /sys/firmware/efi/fw_platform_size)-bit)"
else
	BOOT_MODE="bios"
	echo "Boot mode: BIOS/legacy (no /sys/firmware/efi)"
fi

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

if [[ "$BOOT_MODE" == "uefi" ]]; then
	# GPT: p1 = 1G EFI System (type 1), p2 = swap (type 19), p3 = root (rest).
	fdisk "$DRIVE" <<EOF
g
n


+1G
t
1
n


+$SWAPSIZE
t
2
19
n



w
EOF
else
	# GPT on a BIOS machine: GRUB needs a tiny unformatted "BIOS boot"
	# partition (type 4) to embed its core image, since there's no ESP.
	# p1 = 1M BIOS boot, p2 = swap (type 19), p3 = root (rest). /boot lives
	# on the root filesystem.
	fdisk "$DRIVE" <<EOF
g
n


+1M
t
4
n


+$SWAPSIZE
t
2
19
n



w
EOF
fi

# The kernel does not always re-read the new partition table immediately, so
# the partition device nodes ($P1/$P2/$P3) can be missing or stale when we try
# to format them right away — this is what produces the "ext4 filesystem"
# errors. Force a re-read and wait for udev to create the nodes.
partprobe "$DRIVE"
udevadm settle
for part in "$P1" "$P2" "$P3"; do
	for _ in $(seq 1 10); do
		[[ -b "$part" ]] && break
		sleep 1
	done
done

# format
# -F: never prompt, even if a stale signature is somehow still detected.
mkfs.ext4 -F "$P3"
mkswap "$P2"
if [[ "$BOOT_MODE" == "uefi" ]]; then
	mkfs.fat -F 32 "$P1"
fi

# mount
mount "$P3" /mnt
if [[ "$BOOT_MODE" == "uefi" ]]; then
	mount --mkdir "$P1" /mnt/boot
fi
swapon "$P2"


# installation
# semi minimal install. just need vim for config, network for wifi, and intel-ucode is security.
# BIOS machines boot via GRUB, so pull it in only when needed.
PACSTRAP_PKGS=(base linux linux-firmware vim networkmanager intel-ucode)
if [[ "$BOOT_MODE" == "bios" ]]; then
	PACSTRAP_PKGS+=(grub)
fi
pacstrap -K /mnt "${PACSTRAP_PKGS[@]}"

# genfstab
genfstab -U /mnt >> /mnt/etc/fstab

# Harden the EFI partition mount: only root can read /boot. (UEFI only — on
# BIOS there is no FAT ESP, /boot is just a directory on the root fs.)
if [[ "$BOOT_MODE" == "uefi" ]]; then
	sed -i '/\/boot/ s/fmask=0022/fmask=0077/; /\/boot/ s/dmask=0022/dmask=0077/' /mnt/etc/fstab
fi

# Copy the repo into the new system so post-chroot + first-boot scripts are available.
mkdir -p /mnt/root/arch-setup
cp -r "$SCRIPT_DIR/." /mnt/root/arch-setup/

# Pass the detected boot mode through to the chroot phase (env is not preserved
# across arch-chroot, so persist it in a file the copied repo can read).
echo "BOOT_MODE=$BOOT_MODE" > /mnt/root/arch-setup/boot-mode.env

# Chain straight into the chroot phase — no manual arch-chroot needed.
arch-chroot -S /mnt /root/arch-setup/post-chroot-install.sh

echo
echo "Base install + chroot config complete."
echo "Now: reboot, remove the ISO, log in, then run: /root/arch-setup/install.sh"