#!/bin/bash

set -ouex pipefail

RELEASE="$(rpm -E %fedora)"

echo "Running base configuration for Fedora $RELEASE"
source ../base/build.sh

# Install Awesome WM
#  - include dependencies for default config
echo "Installing Awesome WM"
rpm-ostree install plasma-workspace-x11 awesome picom rofi-wayland rofi-themes rofi-themes-base16 ranger kitty \
  redshift-gtk copyq flameshot autorandr nitrogen barrier \
  xscreensaver-base xscreensaver-extras xscreensaver-gl-base xscreensaver-gl-extras

# Install user dotfiles
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

echo "Configuring Awesome WM"
# Configure Awesome WM
mkdir -p /etc/skel/.config
git clone --depth 1 --recurse-submodules --shallow-submodules https://github.com/syndr/awesome-wm-config.git /etc/skel/.config/awesome

