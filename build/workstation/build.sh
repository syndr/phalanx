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

#echo "Installing Awesome WM"
#source ../awesome/build.sh

echo "Installing Hyprland"
source ../hyprland/build.sh

echo "Installing Utilities"
rpm-ostree install git-delta

echo "Removing unprofessional packages"
rpm-ostree override remove steam steam-devices steam-device-rules lutris

#echo "Installing Productivity Software"
#wget "https://downloads.1password.com/linux/rpm/stable/x86_64/1password-latest.rpm"
#
#rpm-ostree install ./1password-latest.rpm

