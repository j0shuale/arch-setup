#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/vars.sh"

loadkeys $KEYMAP

# i assume at this point you have internet... if not, uncomment
# iwctl --passphrase "$WIFI_PASSPHRASE" station wlan0 connect "$WIFI_SSID"
timedatectl

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
2
19
n



w
EOF

mkfs.ext4 -F "$P3"
mkswap "$P2"
mkfs.fat -F 32 "$P1"

mount "$P3" /mnt
mount --mkdir "$P1" /mnt/boot
swapon "$P2"

pacstrap -K /mnt base linux linux-firmware neovim networkmanager intel-ucode

genfstab -U /mnt >> /mnt/etc/fstab

sed -i '/\/boot/ s/fmask=0022/fmask=0077/; /\/boot/ s/dmask=0022/dmask=0077/' /mnt/etc/fstab

mkdir -p /mnt/root/arch-setup
cp -r "$SCRIPT_DIR/." /mnt/root/arch-setup/

arch-chroot -S /mnt /root/arch-setup/post-chroot-install.sh

