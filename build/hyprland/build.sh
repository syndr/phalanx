#!/bin/bash
# Configuration for Hyprland desktop environment

# Package list for Hyprland configuration
hyprland_packages=(
  # Base packages
  # Note: polkit-kde from base KDE image handles authentication prompts
  hyprland hyprland-plugins hyprpanel pyprland

  # Screen management and utilities
  hypridle hyprlock hyprsunset satty hyprpaper waypaper mpvpaper swww

  # Desktop components
  dunst waybar

  # Screenshot tools
  grim slurp

  # Display management
  wlr-randr kanshi wdisplays

  # Audio control
  pavucontrol pamixer

  # System utilities
  brightnessctl playerctl network-manager-applet blueman btop

  # Scripting and helper tools
  jq socat wl-clipboard
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

# Verify polkit agent is available
if ! rpm -q polkit-kde &>/dev/null; then
  echo "Warning: polkit-kde not found in base image, installing polkit-gnome as fallback"
  hyprland_packages+=(polkit-gnome)
fi

echo "Installing Hyprland and dependencies"
rpm-ostree install "${hyprland_packages[@]}"

