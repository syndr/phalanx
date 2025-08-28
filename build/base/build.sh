#!/bin/bash

set -ouex pipefail

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

