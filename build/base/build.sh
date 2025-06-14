#!/bin/bash

# Check for -v argument in $@
if [[ " $@ " =~ " -v " ]]; then
  TRACE=1
fi

if [[ "${TRACE:-0}" -ne 0 ]]; then
  set -ouex pipefail
else
  set -oue pipefail
fi

RELEASE="$(rpm -E %fedora)"


### Install packages

rpm-ostree install neovim zsh \
  adcli oddjob oddjob-mkhomedir sssd-ad realmd samba-common-tools \
  iptables-nft


### Install user dotfiles

echo "Installing user dotfiles"
dotfile_config_cmd='/usr/bin/git --git-dir=/etc/skel/.cfg/ --work-tree=/etc/skel'
git clone --depth 1 --recurse-submodules --shallow-submodules --bare https://github.com/syndr/dotfiles.git /etc/skel/.cfg
cd /etc/skel
echo ".cfg" >> .gitignore
$dotfile_config_cmd config --local status.showUntrackedFiles no
# Remove existing files
rm -f .zshrc
# Load the dotfiles
$dotfile_config_cmd checkout
