#!/bin/bash
# Configuration for Hyprland desktop environment

# Package list for Hyprland configuration
hyprland_packages=(
  # Base packages
  hyprland hyprland-plugins hyprpanel hyprpolkitagent pyprland

  # Screen management and utilities
  hypridle hyprlock hyprsunset satty hyprpaper waypaper mpvpaper swww
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

echo "Running base configuration for Fedora $RELEASE"
source ../base/build.sh

# Install Hyprland from COPR
#  - include dependencies for default config
echo "Adding solopasha/hyprland COPR repository"
dnf5 copr enable -y solopasha/hyprland

echo "Installing Hyprland and dependencies"
rpm-ostree install "${hyprland_packages[@]}"

