#!/bin/bash
# Phase 3: Post-reboot — services, desktop, firewall, git/SSH
# Run as root after first boot into the new system.
# Usage: /root/arch-setup/03-post-reboot.sh

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

check_root
load_config

log_info "=== Phase 3: Post-reboot setup ==="

# ---------------------------------------------------------------------------
# Network — enable NetworkManager and optionally connect to WiFi
# ---------------------------------------------------------------------------
log_info "Enabling NetworkManager..."
dry_run_exec systemctl enable --now NetworkManager.service

log_info "Checking network connectivity..."
if ! ping -c1 -W2 archlinux.org &>/dev/null; then
    read -r -p "WiFi SSID (leave blank to skip): " WIFI_SSID
    if [[ -n "${WIFI_SSID}" ]]; then
        read -r -s -p "WiFi password: " WIFI_PASS
        echo
        dry_run_exec nmcli device wifi connect "${WIFI_SSID}" password "${WIFI_PASS}"
        unset WIFI_PASS
    fi
else
    log_info "Already connected to network."
fi

# ---------------------------------------------------------------------------
# Ensure packages are installed (safety net — pacstrap covers most of this)
# ---------------------------------------------------------------------------
log_info "Verifying packages with pacman --needed..."
# shellcheck source=lib/packages.sh
source "${SCRIPT_DIR}/lib/packages.sh"
PACKAGES="$(build_package_list)"
# shellcheck disable=SC2086
dry_run_exec pacman -S --needed --noconfirm ${PACKAGES}

# ---------------------------------------------------------------------------
# Display manager
# ---------------------------------------------------------------------------
if [[ " ${PROFILES} " =~ " kde-plasma " ]]; then
    log_info "Enabling SDDM..."
    dry_run_exec systemctl enable sddm
fi

# ---------------------------------------------------------------------------
# X11 keymap (persists into graphical session)
# ---------------------------------------------------------------------------
log_info "Setting X11 keymap to '${KEYMAP}'..."
dry_run_exec localectl set-x11-keymap us pc104 "${KEYMAP}"

# ---------------------------------------------------------------------------
# Firewall (UFW)
# ---------------------------------------------------------------------------
log_info "Configuring UFW firewall..."
dry_run_exec systemctl enable --now ufw.service
dry_run_exec ufw default deny incoming
dry_run_exec ufw default allow outgoing
dry_run_exec ufw enable

# ---------------------------------------------------------------------------
# Git configuration (for USERNAME's home directory)
# ---------------------------------------------------------------------------
log_info "Configuring git for '${USERNAME}'..."
dry_run_exec sudo -u "${USERNAME}" git config --global user.name  "${GIT_NAME}"
dry_run_exec sudo -u "${USERNAME}" git config --global user.email "${GIT_EMAIL}"
dry_run_exec sudo -u "${USERNAME}" git config --global init.defaultBranch main

# ---------------------------------------------------------------------------
# SSH key generation
# ---------------------------------------------------------------------------
log_info "Generating SSH key for '${USERNAME}'..."
SSH_KEY="/home/${USERNAME}/.ssh/id_ed25519"
if [[ ! -f "${SSH_KEY}" ]]; then
    dry_run_exec sudo -u "${USERNAME}" ssh-keygen -t ed25519 -C "${GIT_EMAIL}" -N "" -f "${SSH_KEY}"
    log_info "SSH public key:"
    [[ "${DRY_RUN:-0}" != "1" ]] && cat "${SSH_KEY}.pub"
    log_info "Add the above key to GitHub/GitLab before cloning dotfiles."
else
    log_info "  SSH key already exists at ${SSH_KEY}, skipping."
fi

# ---------------------------------------------------------------------------
# Dotfiles bare-repo scaffold (bare git repo for tracking ~/)
# ---------------------------------------------------------------------------
log_info "Initialising dotfiles bare repo for '${USERNAME}'..."
DOTFILES_DIR="/home/${USERNAME}/.myconf"
if [[ ! -d "${DOTFILES_DIR}" ]]; then
    dry_run_exec sudo -u "${USERNAME}" git init --bare "${DOTFILES_DIR}"
    dry_run_exec sudo -u "${USERNAME}" bash -c "
        /usr/bin/git --git-dir='${DOTFILES_DIR}' --work-tree='/home/${USERNAME}' \
            config status.showUntrackedFiles no
    "
    log_info "  Dotfiles repo initialised at ${DOTFILES_DIR}"
    log_info "  Use 'config' alias to manage dotfiles:"
    log_info "    alias config='/usr/bin/git --git-dir=\$HOME/.myconf/ --work-tree=\$HOME'"
else
    log_info "  Dotfiles repo already exists, skipping."
fi

log_info "=== Phase 3 complete ==="
log_info "Reboot or start SDDM to enter the desktop environment."
