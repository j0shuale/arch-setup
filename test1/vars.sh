WIFI_SSID=""
WIFI_PASSPHRASE=""

DRIVE="/dev/nvme0n1"

# Partition suffix: NVMe/eMMC/loop/mmc devices need a "p" between the disk
# name and the partition number (nvme0n1p1), while SATA/SCSI/IDE disks do not
# (sda1). Auto-detect so the same config works on both the new box and the
# older SATA laptop — just change DRIVE above.
case "$DRIVE" in
	*nvme*|*mmcblk*|*loop*) PART_PREFIX="p" ;;
	*) PART_PREFIX="" ;;
esac

# Partition device paths derived from config.
P1="${DRIVE}${PART_PREFIX}1"  # EFI (UEFI) / BIOS boot (BIOS)
P2="${DRIVE}${PART_PREFIX}2"  # swap
P3="${DRIVE}${PART_PREFIX}3"  # root

TIMEZONE="US/Pacific"
LOCALE="en_US.UTF-8"
KEYMAP="dvorak"

HOSTNAME="odin"
USERNAME="joshu"

SWAPSIZE="32G"  # should be at least as big as RAM for hibernation

GIT_NAME="Joshua Lester"
GIT_EMAIL="josh@joshualester.com"

DOTFILES_DIR="$HOME/dotfiles"
DOTFILES_HTTPS="https://github.com/j0shuale/dotfiles.git"
DOTFILES_SSH="git@github.com:j0shuale/dotfiles.git"

