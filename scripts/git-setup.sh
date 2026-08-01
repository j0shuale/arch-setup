#!/bin/bash

set -e

# ---- config ----
GIT_NAME="Joshua Lester"
GIT_EMAIL="josh@joshualester.com"

# Bare "dotfiles" repo lives at $HOME/dotfiles and is manipulated with the
# `config` alias (defined in the tracked .bashrc). Tracked files check out
# straight into $HOME.
DOTFILES_DIR="$HOME/dotfiles"
DOTFILES_HTTPS="https://github.com/j0shuale/dotfiles.git"
DOTFILES_SSH="git@github.com:j0shuale/dotfiles.git"

# ---- ssh key ----
# generate an ed25519 key non-interactively (no passphrase) if one doesn't exist
KEY="$HOME/.ssh/id_ed25519"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
if [[ ! -f "$KEY" ]]; then
	ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f "$KEY" -N ""
fi

# always use this key and register it with the agent for every host, so you
# don't have to re-add it each session (the recurring ssh headache).
SSH_CONFIG="$HOME/.ssh/config"
if ! grep -qs "IdentityFile $KEY" "$SSH_CONFIG"; then
	cat >> "$SSH_CONFIG" <<EOF
Host *
	AddKeysToAgent yes
	IdentityFile $KEY
EOF
fi
chmod 600 "$SSH_CONFIG"

# ---- dotfiles (bare repo) ----
# helper mirroring the `config` alias so this script can drive the repo.
config() { git --git-dir="$DOTFILES_DIR" --work-tree="$HOME" "$@"; }

if [[ -d "$DOTFILES_DIR" ]]; then
	# already bootstrapped: keep it quiet and pull the latest, non-destructively.
	config config status.showUntrackedFiles no
	config pull --ff-only || echo "warn: could not fast-forward dotfiles; resolve manually."
else
	# Clone over HTTPS first: on a fresh machine the newly generated SSH key
	# isn't registered on GitHub yet, and the repo is public, so HTTPS works
	# without auth. We switch origin to SSH afterward for pushing.
	echo "Cloning dotfiles into $DOTFILES_DIR ..."
	git clone --bare "$DOTFILES_HTTPS" "$DOTFILES_DIR"
	config config status.showUntrackedFiles no

	# Check out tracked files into $HOME, backing up any conflicts first.
	if ! config checkout 2>/dev/null; then
		BACKUP="$HOME/.dotfiles-backup-$(date +%Y%m%d%H%M%S)"
		echo "Backing up pre-existing dotfiles to $BACKUP"
		config checkout 2>&1 | grep -E "^\s+\." | awk '{print $1}' | while read -r f; do
			mkdir -p "$BACKUP/$(dirname "$f")"
			mv "$HOME/$f" "$BACKUP/$f"
		done
		config checkout
	fi

	# Now that the working tree is in place, use SSH for future fetch/push.
	config remote set-url origin "$DOTFILES_SSH"
fi

# Git identity ships in the tracked ~/.gitconfig; only seed a global fallback
# if the dotfiles didn't provide one (e.g. a partial/failed checkout).
if [[ ! -f "$HOME/.gitconfig" ]]; then
	git config --global user.name "$GIT_NAME"
	git config --global user.email "$GIT_EMAIL"
	git config --global init.defaultBranch main
fi

echo
echo "dotfiles setup complete."
echo "To enable pushes from this machine, add its public key to GitHub:"
echo "  cat $KEY.pub"