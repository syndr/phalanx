#!/bin/bash
# Base configuration for Fedora

# Package list for base configuration
base_packages=(
  # Editor and shell
  neovim zsh

  # Domain join and authentication
  adcli oddjob oddjob-mkhomedir sssd-ad realmd samba-common-tools
  iptables-nft

  # System utilities
  gvfs-smb btop

  # KDE add-ons
  kvantum kvantum-data arc-kde-kvantum

  # User utilities
  rofi-wayland rofi-themes rofi-themes-base16 ranger kitty copyq
)


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
echo "Installing base packages"
rpm-ostree install "${base_packages[@]}"

