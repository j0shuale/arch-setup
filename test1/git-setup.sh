KEY="$HOME/.ssh/id_ed25519"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
if [[ ! -f "$KEY" ]]; then
	ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f "$KEY" -N ""
fi

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
