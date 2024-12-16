#!/bin/bash

set -ouex pipefail

RELEASE="$(rpm -E %fedora)"


### Install packages

rpm-ostree install neovim zsh \
  adcli oddjob oddjob-mkhomedir sssd-ad realmd samba-common-tools

# Install Awesome WM
#  - include dependencies for default config
rpm-ostree install plasma-workspace-x11 awesome rofi rofi-themes rofi-themes-base16 ranger kitty

# Configure Awesome WM
mkdir -p /etc/skel/.config
git clone --depth 1 --recurse-submodules --shallow-submodules https://github.com/syndr/awesome-wm-config.git /etc/skel/.config/awesome

