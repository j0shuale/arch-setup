#!/bin/bash

set -e

# set dvorak and change font to bigger
loadkeys dvorak
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

iwctl --passphrase "password" station wlan0 connect "network-name"
timedatectl

# partitioning

DRIVE="/dev/nvme0n1"

echo "Partitioning $DRIVE..."

fdisk "$DRIVE" <<EOF
g
n


+1G
t
1
n


+16G
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
mkfs.ext4 /dev/nvme0n1p3
mkswap /dev/nvme0n1p2
mkfs.fat -F 32 /dev/nvme0n1p1
# mount
mount /dev/nvme0n1p3 /mnt
mount --mkdir /dev/nvme0n1p1 /mnt/boot
swapon /dev/nvme0n1p2


# installation
# semi minimal install. just need vim for config, network for wifi, and intel-ucode is security
pacstrap -K /mnt base linux linux-firmware vim networkmanager intel-ucode

# genfstab
genfstab -U /mnt >> /mnt/etc/fstab

# now is the time i chroot into the system. i'm copying this over.
# you might have to do arch-chroot -S. mine wasn't able to recognize the systemd-boot loader. i had to redo things and i'm not exactly sure why
arch-chroot -S /mnt