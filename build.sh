#!/bin/bash

set -ouex pipefail

RELEASE="$(rpm -E %fedora)"


### Install packages

rpm-ostree install neovim zsh \
  adcli oddjob oddjob-mkhomedir sssd-ad realmd samba-common-tools

# Install Awesome WM
#  - include dependencies for default config
rpm-ostree install plasma-workspace-x11 awesome rofi rofi-themes rofi-themes-base16 ranger kitty \
  redshift-gtk copyq flameshot autorandr nitrogen barrier \
  xscreensaver-base xscreensaver-extras xscreensaver-gl-base xscreensaver-gl-extras

# Install user dotfiles
dotfile_config_cmd='/usr/bin/git --git-dir=/etc/skel/.cfg/ --work-tree=/etc/skel'
git clone --depth 1 --recurse-submodules --shallow-submodules --bare https://github.com/syndr/dotfiles.git /etc/skel/.cfg
cd /etc/skel
echo ".cfg" >> .gitignore
$dotfile_config_cmd config --local status.showUntrackedFiles no
# Remove existing files
rm -f .zshrc
# Load the dotfiles
$dotfile_config_cmd checkout

# Configure Awesome WM
mkdir -p /etc/skel/.config
git clone --depth 1 --recurse-submodules --shallow-submodules https://github.com/syndr/awesome-wm-config.git /etc/skel/.config/awesome

