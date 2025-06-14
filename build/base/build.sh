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


### Install domain support packages
echo "Installing domain support packages"
rpm-ostree install \
  adcli oddjob oddjob-mkhomedir sssd-ad realmd samba-common-tools \
  iptables-nft

echo "Installing shell fundamentals"
rpm-ostree install zsh kitty neovim

echo "Installing system utilities"
rpm-ostree install gvfs-smb btop

echo "Installing KDE add-ons"
rpm-ostree install kvantum kvantum-data arc-kde-kvantum

