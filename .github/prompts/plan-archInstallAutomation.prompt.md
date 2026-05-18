# Plan: Arch Install Scripts — Best Practice Automation

Refactor into a config-driven, semi-automated install system with hardware profiles, proper error handling, and zero hardcoded secrets. You manually trigger each phase (pre-chroot → chroot → post-reboot) but each phase runs unattended after initial prompts.

---

## Architecture

```
arch-setup/
├── config.sh.example      # Template config (committed)
├── config.sh              # User's actual config (gitignored)
├── lib/
│   ├── common.sh          # Shared functions (logging, error handling, prompts)
│   └── packages.sh        # Package list builder from profiles
├── profiles/
│   ├── base.txt           # Always installed
│   ├── intel-laptop.txt   # Intel CPU + integrated graphics
│   ├── amd-nvidia-desktop.txt  # AMD CPU + NVIDIA GPU
│   ├── kde-plasma.txt     # DE packages
│   ├── gaming.txt         # Steam, gamemode, etc.
│   └── audio-production.txt
├── 01-pre-chroot.sh       # Phase 1: partition, format, pacstrap
├── 02-chroot.sh           # Phase 2: locale, bootloader, users
├── 03-post-reboot.sh      # Phase 3: services, DE, firewall, git
├── .gitignore
└── README.md
```

---

## Steps

### Phase A: Foundation (do first)

1. **Create `config.sh.example`** — All tuneable values: `DRIVE`, `HOSTNAME`, `USERNAME`, `TIMEZONE`, `KEYMAP`, `LOCALE`, `SWAP_SIZE`, `EFI_SIZE`, `PROFILES` array
2. **Create `lib/common.sh`** — `log_info/warn/error`, `check_root`, `confirm_step`, `load_config` (validates required vars), partition-name helper (handles both `/dev/sdX1` and `/dev/nvme0n1p1` naming)
3. **Create `.gitignore`** — Exclude `config.sh`

### Phase B: Package Profiles (*parallel with A*)

4. **Create profile files** — One package per line; `base.txt`, `intel-laptop.txt`, `amd-nvidia-desktop.txt`, `kde-plasma.txt`, `gaming.txt`, `audio-production.txt`
5. **Create `lib/packages.sh`** — `build_package_list()` reads `PROFILES` config, concatenates files, deduplicates

### Phase C: Script Rewrites (*depends on A+B*)

6. **Rewrite `01-pre-chroot.sh`** — Source lib/config; prompt WiFi at runtime with `read -s`; derive partition names from `$DRIVE`; partition using config sizes; pacstrap with profile-built package list; copy scripts into `/mnt/root/` for next phase
7. **Rewrite `02-chroot.sh`** — Source lib/config; **fix UUID bug** (currently `UUID=lsblk` instead of `UUID=$(blkid ...)`); set timezone/locale/keymap/hostname from config; fix fmask/dmask to 0077 in fstab; install bootloader with correct UUID; create user; lock root; validate sudoers with `visudo -c`
8. **Rewrite `03-post-reboot.sh`** — Enable NetworkManager + WiFi prompt; `pacman -S --needed` remaining packages; enable display manager; set keymap; inline firewall (UFW); inline git/SSH/dotfiles setup

### Phase D: Polish

9. **Create `README.md`** — Prerequisites, usage steps, how to add profiles
10. **Remove obsolete files** — Old scripts, `requirements.txt`, `gaming?/`, `todo.md` (all absorbed)

---

## Verification

1. `shellcheck` all `.sh` files — must pass clean
2. `DRY_RUN=1` mode in `lib/common.sh` that prints commands instead of executing — test all phases
3. Run without `config.sh` → should error with helpful message
4. `build_package_list` unit test with different profile combos
5. Full end-to-end in a QEMU VM

---

## Key Bugs Fixed

- **Broken UUID capture** in `post-chroot-install.sh:24`: `UUID=lsblk -dno UUID ...` → `UUID=$(blkid -s UUID -o value ...)`
- **Inconsistent partition references**: uses `$DRIVE` variable then hardcodes `/dev/nvme0n1p3` for mkfs/mount
- **WiFi password in plaintext** in source control
- **Package list divergence** between `install.sh` and `requirements.txt`
- **Missing fmask/dmask** security fix (noted in comment but never applied)

---

## Decisions

- Keep custom scripts (no archinstall)
- Semi-automated: manual trigger per phase, unattended within each phase
- WiFi: runtime prompt with `read -s`, never persisted
- Hardware differences via profile selection in config
- systemd-boot remains the bootloader
- **Out of scope**: DNS security, system maintenance cron jobs, zsh config, LUKS encryption (future work)

---

## Further Considerations

1. **Hibernation**: Swap is sized for it but `resume` hook isn't in mkinitcpio — recommend adding in Phase 2
2. **AUR helper**: Some packages (spotify-launcher, discord) need `yay`  — recommend optional bootstrap in Phase 3 with `profiles/aur-gaming.txt`
3. **LUKS encryption**: Recommend as a future config flag, not blocking this refactor
