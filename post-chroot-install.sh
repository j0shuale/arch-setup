#!/bin/bash

set -e

# random locale/time stuff
ln -sf /usr/share/zoneinfo/US/Pacific /etc/localtime

hwclock --systohc

sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen

locale-gen

echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "KEYMAP=dvorak" >> /etc/vconsole.conf

echo "freyja" > /etc/hostname

# set up password (i think for root)
passwd

# before you do this, you should probably modify /etc/fstab 's boot entry to change fmask and dmask to 0077 instead of 0022 for security purposes. look into this/why?
mkinitcpio -P
bootctl install
UUID=$(lsblk -dno UUID /dev/nvme0n1p3)
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


