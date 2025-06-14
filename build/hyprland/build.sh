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

echo "Running base configuration for Fedora $RELEASE"
source ../base/build.sh

# Install Hyprland from COPR
#  - include dependencies for default config
echo "Adding solopasha/hyprland COPR repository"
dnf5 copr enable -y solopasha/hyprland

echo "Installing Hyprland and dependencies"
rpm-ostree install hyprland hyprland-plugins hyprpanel hypridle hyprlock hyprpolkitagent \
  hyprsunset satty pyprland hyprpaper waypaper mpvpaper swww

