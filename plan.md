# Plan: Bare-repo dotfiles at `~/dotfiles`

Set up the Atlassian bare-repo technique using `~/dotfiles` itself as the bare Git directory and `$HOME` as the work-tree, driven by a `config` alias in zsh. First tracked files: `.zshrc`, `.gitconfig`, and vim/nvim config.

**Steps**

*Phase 1 — Create the bare repo*
1. Run `git init --bare $HOME/dotfiles` so the bare Git internals live directly in `~/dotfiles`.

*Phase 2 — Wire up the alias (zsh)*
2. Define the alias in the current shell and append it to `~/.zshrc`:
   `alias config='/usr/bin/git --git-dir=$HOME/dotfiles/ --work-tree=$HOME'` *(depends on 1)*
3. Hide noise: `config config --local status.showUntrackedFiles no` *(depends on 1)*

*Phase 3 — Recursion guard*
4. `echo "dotfiles" >> ~/.gitignore` so the bare folder inside `$HOME` never tries to track itself, then `config add ~/.gitignore`. *(depends on 2)*

*Phase 4 — Track initial dotfiles* *(depends on 2)*
5. `config add` the initial set: `~/.zshrc`, `~/.gitconfig`, `~/.vimrc` (and `~/.config/nvim/` if present), then `config commit -m "Initial dotfiles"`.

*Phase 5 — Remote + convenience (optional)*
6. Add a remote and `config push -u origin main` (needs a remote URL from you).
7. Optionally add a `bootstrap.sh` install script (clone `--bare`, backup conflicts, checkout, set `showUntrackedFiles no`) and a `README.md` documenting the workflow.

**Relevant files**
- `~/dotfiles/` — becomes the bare Git dir (no working tree checked out here).
- `~/.zshrc` — holds the `config` alias; also tracked.
- `~/.gitignore` — must contain `dotfiles` to prevent self-tracking recursion.
- `~/.gitconfig`, `~/.vimrc`, `~/.config/nvim/` — tracked content.

**Verification**
1. `config status` runs without error and shows a clean/expected tree (no `$HOME` untracked spam).
2. `config log --oneline` shows the initial commit.
3. Open a new zsh session: `type config` resolves to the alias.
4. `git status` inside an unrelated repo in `$HOME` is unaffected (no interference).
5. (If pushed) remote shows the commit.

**Decisions**
- Bare dir = `~/dotfiles` (your choice) rather than the classic `~/.cfg`; alias uses `--git-dir=$HOME/dotfiles/`.
- Shell = zsh; alias appended to `~/.zshrc`.
- No symlinks — files stay in place and are tracked directly (core benefit of this method).

**Further Considerations**
1. Remote hosting for `config push` — do you have a repo URL yet? Option A: GitHub SSH, Option B: HTTPS, Option C: skip remote for now (local-only).
2. Include a `bootstrap.sh` + `README.md` for setting up on new machines? Recommend **yes** (matches the article's install-script pattern). Option A: yes / Option B: no.
3. Branch name for the initial commit — Option A: `main` (recommended) / Option B: `master`.