#!/bin/bash
# Run this AFTER the first reboot, logged in as root on the installed system.
#   /root/arch-setup/install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Log everything (stdout + stderr) to a timestamped file, while still showing it live.
mkdir -p "$SCRIPT_DIR/logs"
LOG_FILE="$SCRIPT_DIR/logs/install-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

source "$SCRIPT_DIR/vars.sh"

# user add (skip if it already exists so this is re-runnable)
if ! id -u "$USERNAME" >/dev/null 2>&1; then
	useradd -m "$USERNAME"
fi
# Set the user password.
echo "Set the password for $USERNAME:"
passwd "$USERNAME"

# network connect
systemctl enable --now NetworkManager.service
read -rsp "Wifi SSID: " WIFI_SSID
echo
read -rsp "Wifi passphrase for '$WIFI_SSID': " WIFI_PASSPHRASE
echo
if [[ -z "${WIFI_PASSPHRASE:-}" ]]; then
	nmcli d wifi connect "$WIFI_SSID" --ask
else
	nmcli d wifi connect "$WIFI_SSID" --password "$WIFI_PASSPHRASE"
fi

# install pacman stuff (maybe change to pull my main overall list)
pacman -S --needed --noconfirm $(<"$SCRIPT_DIR/scripts/reqs.txt")

# firewall: default-deny incoming, allow outgoing (from scripts/firewall.sh)
bash "$SCRIPT_DIR/scripts/firewall.sh"

# security stuff
# Grant sudo via a drop-in. Validate before applying so we can't lock ourselves out.
SUDOERS_FILE="/etc/sudoers.d/90-${USERNAME}"
echo "${USERNAME} ALL=(ALL:ALL) ALL" > "$SUDOERS_FILE"
chmod 0440 "$SUDOERS_FILE"
visudo -cf "$SUDOERS_FILE"
passwd -l root

systemctl enable plasmalogin.service

# keyboard layout for X11 / Plasma
localectl set-x11-keymap us pc104 $KEYMAP

# per-user setup, run AS the user: generates the ssh key, then clones the
# dotfiles bare repo into ~/dotfiles and checks it out into $HOME. Needs the
# network (connected above) since it pulls from GitHub.
runuser -u "$USERNAME" -- bash "$SCRIPT_DIR/scripts/git-setup.sh"

echo
echo "First-boot setup complete. Reboot to start Plasma."
echo "Remember to add ${USERNAME}'s new SSH public key to GitHub to enable dotfiles pushes:"
echo "  cat /home/${USERNAME}/.ssh/id_ed25519.pub"
