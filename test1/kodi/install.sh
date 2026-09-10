#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

sudo pacman -S --needed --noconfirm $(<"$SCRIPT_DIR/reqs.txt")

while IFS= read -r package || [ -n "$package" ]; do
  if [ -d "$package" ]; then
    rm -rf $package
  fi
  git clone https://aur.archlinux.org/$package
  cd $package
  makepkg -si --noconfirm
  cd ..
  rm -rf $package
done < aur-reqs.txt
