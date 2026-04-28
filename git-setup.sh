#!/bin/bash

set -e

sudo pacman -S git openssh
git config --global user.name "Joshua Lester"
git config --global user.email "josh@joshualester.com"
git config --global init.defaultBranch main
ssh-keygen -t ed25519 -C "josh@joshualester.com"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

git init --bare $HOME/.myconf
alias config='/usr/bin/git --git-dir=$HOME/.myconf/ --work-tree=$HOME'
config config status.showUntrackedFiles no