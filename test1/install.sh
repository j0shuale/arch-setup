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

pacman -S --needed --noconfirm $(<"$SCRIPT_DIR/test1/reqs.txt")

systemctl enable --now ufw.service
ufw default deny incoming
ufw default allow outgoing
ufw enable

SUDOERS_FILE="/etc/sudoers.d/90-${USERNAME}"
echo "${USERNAME} ALL=(ALL:ALL) ALL" > "$SUDOERS_FILE"
chmod 0440 "$SUDOERS_FILE"
visudo -cf "$SUDOERS_FILE"
passwd -l root

KEY="$HOME/.ssh/id_ed25519"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
if [[ ! -f "$KEY" ]]; then
	ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f "$KEY" -N ""
fi

chmod 600 "$SSH_CONFIG"

config() { git --git-dir="$DOTFILES_DIR" --work-tree="$HOME" "$@"; }

git clone --bare "$DOTFILES_HTTPS" "$DOTFILES_DIR"
config config status.showUntrackedFiles no

if ! config checkout 2>/dev/null; then
	BACKUP="$HOME/.dotfiles-backup-$(date +%Y%m%d%H%M%S)"
	echo "Backing up pre-existing dotfiles to $BACKUP"
	config checkout 2>&1 | grep -E "^\s+\." | awk '{print $1}' | while read -r f; do
		mkdir -p "$BACKUP/$(dirname "$f")"
		mv "$HOME/$f" "$BACKUP/$f"
	done
	config checkout
fi
