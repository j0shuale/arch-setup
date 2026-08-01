DRIVE="/dev/nvme0n1"
PART_PREFIX="p"

# Partition device paths derived from config.
P1="${DRIVE}${PART_PREFIX}1"  # EFI
P2="${DRIVE}${PART_PREFIX}2"  # swap
P3="${DRIVE}${PART_PREFIX}3"  # root

TIMEZONE="US/Pacific"
LOCALE="en_US.UTF-8"
KEYMAP="dvorak"

HOSTNAME="odin"
USERNAME="joshu"

SWAPSIZE="32G"  # should be at least as big as RAM for hibernation