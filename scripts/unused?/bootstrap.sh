#!/bin/bash
# Optional convenience script to run on a FRESH live Arch ISO to enable
# remote install over SSH from another machine.
#
# On the live ISO (physical keyboard):
#   passwd                      # set a temporary root password for this session
#   pacman -Sy git              # (usually already present on the ISO)
#   git clone <your-repo-url> arch-setup
#   ./arch-setup/bootstrap.sh   # prints the IP to SSH into
#
# Then from your laptop:
#   ssh root@<printed-ip>
#   cd arch-setup
#   cp config.env.example config.env && vim config.env   # fill in values
#   ./pre-chroot-install.sh

set -euo pipefail

# Bring up sshd so you can drive the rest of the install remotely.
systemctl start sshd

echo "sshd is running. Connect from another machine with:"
echo
ip -brief addr show | awk '$1 != "lo" {print "  ssh root@" $3}' | sed 's#/.*##'
echo
echo "Make sure you have set a root password (run: passwd) before connecting."
