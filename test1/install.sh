#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/vars.sh"

useradd -m "$USERNAME"

passwd "$USERNAME"

systemctl enable --now NetworkManager.service
read -rsp "Wifi SSID: " WIFI_SSID
echo
nmcli --ask d wifi connect "$WIFI_SSID"

pacman -S --needed --noconfirm $(<"$SCRIPT_DIR/reqs.txt")

# plasma things..
pacman -S --needed --noconfirm $(<"$SCRIPT_DIR/plasma-reqs.txt")

systemctl enable --now ufw.service
ufw default deny incoming
ufw default allow outgoing
ufw enable

SUDOERS_FILE="/etc/sudoers.d/90-${USERNAME}"
echo "${USERNAME} ALL=(ALL:ALL) ALL" > "$SUDOERS_FILE"
chmod 0440 "$SUDOERS_FILE"
visudo -cf "$SUDOERS_FILE"
passwd -l root

runuser -u "$USERNAME" -- bash -s < "$SCRIPT_DIR/git-setup.sh"


