#!/bin/bash

set -e

# user add
useradd -m joshu
passwd joshu

# network connect
systemctl enable --now NetworkManager.service
nmcli d wifi connect NETGEAR31 --ask

# install pacman stuff (maybe change to pull my main overall list)
pacman -S # requirements.txt

# security stuff
echo "joshu freyja=(ALL:ALL) ALL" >> /etc/sudoers.d/90-joshu
passwd -l root
echo "Defaults pwfeedback" >> /etc/sudoers.d/10-pwfeedback

systemctl enable plasmalogin.service

# reboot


sudo localectl set-x11-keymap us pc104 dvorak
