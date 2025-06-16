#!/bin/bash
# Workstation-specific configuration for Fedora

# Package list for workstation configuration
workstation_packages=(
  # Git and diff tools
  git-delta
)

# Unprofessional packages that should be removed
workstation_packages_remove=(
  steam steam-devices steam-device-rules lutris
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

#echo "Installing Awesome WM"
#source ../awesome/build.sh

echo "Installing Hyprland"
source ../hyprland/build.sh

echo "Installing Workstation packages"
rpm-ostree install "${workstation_packages[@]}"

echo "Removing unprofessional packages"
rpm-ostree override remove "${workstation_packages_remove[@]}"

#echo "Installing Productivity Software"
#wget "https://downloads.1password.com/linux/rpm/stable/x86_64/1password-latest.rpm"
#
#rpm-ostree install ./1password-latest.rpm

