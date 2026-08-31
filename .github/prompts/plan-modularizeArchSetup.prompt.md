# Plan: Modularize arch-setup into profiles + modules

Refactor the repo so install phases stay generic while machine/profile-specific
behavior lives in composable **profiles** (personal/work/htpc) and **modules**
(firewall, gaming, dev, dotfiles, etc.). Profile chosen via `PROFILE=` env var.
pacman-only. Base vars + per-profile override layer.

## Target layout
```
install.sh                     # phase 3 orchestrator (generic)
pre-chroot-install.sh          # unchanged flow, sources vars via loader
post-chroot-install.sh         # unchanged flow, sources vars via loader
lib/
  common.sh                    # log(), run helpers, install_packages(), resolve module dirs
  load-vars.sh                 # source vars.sh then profiles/<PROFILE>/vars.sh override
profiles/
  personal/
    profile.conf               # MODULES=(dotfiles firewall dev gaming ...)
    vars.sh                    # HOSTNAME/USERNAME/TIMEZONE overrides
    reqs.txt                   # profile-level base packages
  work/ { profile.conf, vars.sh, reqs.txt }
  htpc/ { profile.conf, vars.sh, reqs.txt }
modules/
  firewall/  { module.sh, reqs.txt }
  dotfiles/  { module.sh }            # from git-setup.sh
  base/      { reqs.txt }             # shared core pkgs
  gaming/    { reqs.txt, module.sh }
  dev/       { reqs.txt }
vars.sh                        # base/default values (machine-neutral defaults)
notes/ ...
```

## Steps

### Phase 1 — Shared library + var loading
1. Create `lib/common.sh`: `log()`, `install_packages <file...>` (concatenates
   reqs files, `pacman -S --needed --noconfirm`), `run_module <name>`,
   `active_modules()` (reads profile.conf), path resolution via `$SCRIPT_DIR`.
2. Create `lib/load-vars.sh`: sources base `vars.sh`, then if
   `profiles/$PROFILE/vars.sh` exists, sources it (override layer). Validates
   `PROFILE` is set/known; default `PROFILE=personal`.

### Phase 2 — Split reqs + create modules  (*parallel with Phase 1*)
3. Move shared core packages from `scripts/reqs.txt` into `modules/base/reqs.txt`.
4. Create `modules/firewall/` (module.sh = current `scripts/firewall.sh`, plus
   optional `reqs.txt` with `ufw`).
5. Create `modules/dotfiles/module.sh` from `scripts/git-setup.sh` (keep
   git identity vars overridable via profile vars).
6. Create feature modules: `dev/reqs.txt`, `gaming/reqs.txt`(+module.sh),
   split KDE/desktop pkgs into `modules/desktop/reqs.txt`.

### Phase 3 — Profiles
7. Create `profiles/personal/` (mirrors current odin/joshu config: HOSTNAME=odin,
   full desktop+dotfiles+gaming), `profiles/work/`, `profiles/htpc/`.
8. Each `profile.conf` declares ordered `MODULES=(...)`; each `vars.sh` overrides
   HOSTNAME/USERNAME/TIMEZONE etc.; each `reqs.txt` optional extras.

### Phase 4 — Rewire orchestrators
9. `install.sh`: source `lib/load-vars.sh` + `lib/common.sh`; gather reqs from
   `modules/base` + each active module + profile reqs → single
   `install_packages` call; then run each module's `module.sh` in order
   (respecting root vs `runuser $USERNAME` context — dotfiles runs as user).
10. `pre-chroot-install.sh` / `post-chroot-install.sh`: replace direct
    `source vars.sh` with `lib/load-vars.sh`; propagate `PROFILE` into chroot
    (write to `profile.env` alongside existing `boot-mode.env`, and copy repo).

### Phase 5 — Cleanup + docs
11. Remove obsolete `scripts/reqs.txt`, retire `scripts/` (or keep thin
    wrappers). Delete stray `scripts/unused?/`, `gaming?/` placeholders.
12. Update `notes/` and add a short README section on adding a module/profile.

## Relevant files
- `install.sh` — becomes generic orchestrator; replace hardcoded reqs read + firewall/git calls with module loop
- `vars.sh` — strip machine-specifics to profiles; keep neutral defaults + PART_PREFIX derivation
- `pre-chroot-install.sh` / `post-chroot-install.sh` — swap var sourcing to loader, pass PROFILE through chroot
- `scripts/firewall.sh` → `modules/firewall/module.sh`
- `scripts/git-setup.sh` → `modules/dotfiles/module.sh` (params from profile vars)
- `scripts/reqs.txt` → split into `modules/*/reqs.txt`

## Verification
1. `PROFILE=personal bash -n install.sh` and `shellcheck` all scripts (syntax).
2. Dry-run mode: add `DRY_RUN=1` to `install_packages`/`run_module` to echo
   actions; run each profile, confirm expected module + package set printed.
3. Boot a throwaway VM (or loop device `DRIVE=/dev/loopX`) and run full
   pre→post→install with `PROFILE=htpc`; confirm only HTPC modules applied.
4. Re-run `install.sh` to confirm idempotency (`--needed`, id checks, ssh key guard).

## Decisions
- Profile selected via `PROFILE=` env var (default `personal`).
- Module = folder with optional `reqs.txt` + optional `module.sh` + config.
- Base `vars.sh` + `profiles/<p>/vars.sh` override layer.
- pacman-only; no AUR/yay (leave `install_packages` as the single choke point to add later).
- Modules ordered explicitly in `profile.conf` MODULES array.

## Further considerations
1. Module run context: dotfiles must run as user, firewall as root. Recommend a
   convention — `module.sh` runs as root; a module may include `user.sh` run via
   `runuser`. Option A: two files. Option B: metadata line in module.sh.
2. Should `pre/post-chroot` be profile-aware at all, or only `install.sh`?
   Recommend passing PROFILE through but only `install.sh` acts on modules;
   chroot phase just uses profile vars (hostname/timezone).
