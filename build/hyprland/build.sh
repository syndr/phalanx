#!/bin/bash
# Configuration for Hyprland desktop environment

# COPR Repos and packages needed from them
# lionheartp/Hyprland - hyprland, hyprpolkitagent, swww, cliphist
# erikreider/SwayNotificationCenter - SwayNotificationCenter
# errornointernet/packages - wallust
# tofik/nwg-shell - nwg-displays, nwg-look

# List of COPR repositories to be added and enabled
# solopasha/hyprland   # No longer getting updated
# Replaced with sdegler/hypr-test 11/21/2025
# Replaced sdegler/hypr-test with lionheartp/Hyprland  11/24/25

copr_repos=(
    # Enable for Fedora 43 and later
    lionheartp/Hyprland

    # Original source, maintainer appears to be AWOL!
    #solopasha/hyprland

    erikreider/SwayNotificationCenter
    errornointernet/packages
    tofik/nwg-shell

    # For swww
    alebastr/sway-extras
)

# need to add: swww, hyprland-qtutils
# Package list for Hyprland configuration
hyprland_packages=(
  # Core Hyprland (polkit agent added conditionally below due to Qt conflicts on NVIDIA)
  hyprland-git hyprland-git-uwsm

  # Terminal and launchers
  kitty wlogout

  # Theming and appearance
  kvantum qt5ct qt6ct qt6-qtsvg nwg-look hyprcursor hyprland-qt-support
  hyprland-guiutils

  # Wallpaper and color
  swww wallust

  # Desktop components
  waybar SwayNotificationCenter nwg-displays quickshell

  # Screen locking and power management
  hyprlock hypridle

  # Screenshot tools
  grim slurp swappy

  # Audio and media
  pavucontrol pamixer pipewire-alsa pipewire-utils playerctl
  mpv mpv-mpris cava

  # System utilities
  brightnessctl btop gnome-system-monitor nvtop
  network-manager-applet gvfs gvfs-mtp
  inxi fastfetch loupe mousepad qalculate-gtk yad

  # Scripting and helper tools
  bc curl findutils gawk git ImageMagick jq openssl unzip wget2
  wl-clipboard cliphist xdg-user-dirs xdg-utils
  python3-requests python3-pip python3-pyquery

  # Extras
  hyprutils hyprgraphics hyprlang aquamarine
)

# Development packages for hyprpm plugin building
hyprland_plugin_build_deps=(
  # Build tools
  meson cmake gcc-c++ ninja-build

  # Hyprland development headers
  #hyprland-devel
  hyprwayland-scanner-devel hyprlang-devel hyprcursor-devel
  hyprutils-devel hyprgraphics-devel

  # Wayland development
  wayland-devel wayland-protocols-devel

  # Graphics development
  libX11-devel aquamarine-devel

  # Input and display
  libxcb-devel libxkbcommon-devel libXcursor-devel libinput-devel
  xcb-util-wm-devel xcb-util-errors-devel

  # Misc libraries
  re2-devel libuuid-devel tomlplusplus-devel

  # Rendering libraries
  pixman-devel cairo-devel pango-devel

  # OpenGL/GLES development
  mesa-libGL-devel mesa-libGLES-devel mesa-libEGL-devel mesa-libgbm-devel
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

# Configure COPR repositories
echo "Enabling required COPR repositories"
for repo in "${copr_repos[@]}"; do
  echo "Enabling COPR repository: $repo"
  dnf5 copr enable -y "$repo"
done

# Add polkit agent - hyprpolkitagent requires Qt 6.9 but NVIDIA images ship Qt 6.10
# Base bazzite image includes polkit-kde, so we fall back to that when hyprpolkitagent won't work
QT_VERSION=$(rpm -q qt6-qtbase --queryformat '%{VERSION}' 2>/dev/null || echo "unknown")
echo "Detected Qt version: $QT_VERSION"
if [[ "$QT_VERSION" == 6.10* ]]; then
  echo "Qt 6.10 detected - using polkit-kde from base image (hyprpolkitagent requires Qt 6.9)"
else
  echo "Using hyprpolkitagent"
  hyprland_packages+=(hyprpolkitagent)
fi

echo "Installing Hyprland and dependencies"
rpm-ostree install "${hyprland_packages[@]}"

echo "Installing plugin build dependencies (for hyprpm)"
rpm-ostree install "${hyprland_plugin_build_deps[@]}"

