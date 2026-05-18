# arch-setup

Config-driven, semi-automated Arch Linux install scripts.  
You manually trigger each phase; each phase runs unattended after its initial prompts.

---

## Prerequisites

- Booted from the [Arch Linux ISO](https://archlinux.org/download/) in UEFI mode
- Internet access (ethernet, or WiFi credentials ready for the prompt)
- `shellcheck` available if you want to lint the scripts

---

## Quick Start

### 1. Create your config

```bash
cp config.sh.example config.sh
vim config.sh        # set DRIVE, HOSTNAME, USERNAME, TIMEZONE, KEYMAP, PROFILES, etc.
```

`config.sh` is gitignored and will never be committed.

### 2. Phase 1 — Partition, format, pacstrap (live ISO)

```bash
bash 01-pre-chroot.sh
```

Partitions `$DRIVE`, formats, mounts, runs `pacstrap` with your profile packages, generates fstab, and copies the scripts into `/mnt/root/arch-setup/` for the next phase.

### 3. Phase 2 — Locale, bootloader, users (inside chroot)

```bash
arch-chroot /mnt /root/arch-setup/02-chroot.sh
```

Sets timezone/locale/keymap/hostname, adds the `resume` mkinitcpio hook, installs systemd-boot with correct UUIDs, creates your user, configures sudoers, locks root.

Exit chroot and reboot:

```bash
exit
umount -R /mnt
reboot
```

### 4. Phase 3 — Services, desktop, firewall, git/SSH (first boot)

Log in as root, then:

```bash
/root/arch-setup/03-post-reboot.sh
```

Enables NetworkManager, optionally connects WiFi, enables SDDM, configures UFW, sets up git identity, generates an SSH key, and initialises a dotfiles bare repo.

---

## Profiles

Hardware and software differences are handled via profiles in `profiles/`.  
Set `PROFILES` in `config.sh` as a space-separated list.

| Profile               | Contents                                      |
|-----------------------|-----------------------------------------------|
| `base`                | Core packages — always required               |
| `intel-laptop`        | `intel-ucode`                                 |
| `amd-nvidia-desktop`  | `amd-ucode`, `nvidia-open`, utils             |
| `kde-plasma`          | Plasma desktop, SDDM, apps                    |
| `gaming`              | Steam, gamemode, mangohud, tools              |
| `audio-production`    | ALSA utils, pavucontrol, qpwgraph             |

### Adding a profile

1. Create `profiles/myprofile.txt` with one package per line.
2. Add `# comments` for clarity; blank lines are ignored.
3. Add `myprofile` to `PROFILES` in `config.sh`.

### AUR packages

`spotify-launcher` and `alsa-scarlett-gui` require an AUR helper (`yay`).  
Install `yay` manually after Phase 3, then install AUR packages.  
A future `profiles/aur-gaming.txt` is planned.

---

## Dry-run mode

Prefix any phase script with `DRY_RUN=1` to print commands without executing:

```bash
DRY_RUN=1 bash 01-pre-chroot.sh
```

---

## Key design decisions

- **No hardcoded secrets** — WiFi passwords are prompted at runtime with `read -s` and never persisted
- **No archinstall** — custom scripts give full control
- **systemd-boot** — simple, no GRUB
- **fmask/dmask 0077** on the EFI partition for security
- **Hibernation** — `resume` hook added and swap UUID passed to kernel options
- **Bootloader UUID** — uses `blkid` (fixes the broken `UUID=lsblk` bug from the old scripts)

---

## Out of scope (future work)

- DNS security (DoH/DoT)
- LUKS full-disk encryption
- System maintenance cron jobs
- Zsh configuration
