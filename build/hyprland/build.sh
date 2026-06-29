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

# Package list for Hyprland configuration
hyprland_packages=(
  # Core Hyprland (polkit agent added conditionally below due to Qt conflicts on NVIDIA)
  hyprland

  # Terminal and launchers
  kitty wlogout

  # Theming and appearance
  # Fixes Qt-Quick / Kvantum styling under Hyprland (dotfiles installer warnings):
  #   - kvantum-qt6: Qt6 Kvantum engine so the Kvantum (Hackerer-Dark) theme applies
  #     to Qt6 widget apps. On Fedora 44 this is shipped inside the `kvantum` package
  #     (which Provides kvantum-qt6); listed explicitly to document the requirement.
  #   - hyprland-guiutils: formerly `hyprland-qtutils` (which it Obsoletes); provides
  #     hyprland-share-picker (Wayland screen-share dialog). The org.hyprland.style
  #     QtQuick module lives in hyprland-qt-support, layered conditionally below once
  #     the base image ships Qt >= 6.11.
  kvantum kvantum-qt6 qt5ct qt6ct qt6-qtsvg nwg-look hyprcursor hyprland-guiutils

  # Wallpaper and color
  swww wallust

  # Desktop components
  waybar SwayNotificationCenter nwg-displays quickshell

  # Lan Mouse GitHub binary runtime deps (installed under non-RPM paths to avoid RPM collisions)
  libadwaita gtk4 libX11 libXtst

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

  # Scripting and helper tools (curl/jq are also used to resolve the Lan Mouse GitHub release)
  bc curl findutils gawk git ImageMagick jq openssl unzip wget2
  wl-clipboard cliphist xdg-user-dirs xdg-utils
  python3-requests python3-pip python3-pyquery

  # Extras
  hyprutils hyprgraphics hyprlang aquamarine
)

# Development packages for hyprpm plugin building
# NOTE: These are NOT installed on the base image due to gcc version conflicts.
# Instead, use the hyprland-build distrobox container for plugin compilation.
# Run: ujust setup-hyprland-build create
# Then: ujust setup-hyprland-build enter
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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Running base configuration for Fedora $RELEASE"
source ../base/build.sh

# Configure COPR repositories
echo "Enabling required COPR repositories"
for repo in "${copr_repos[@]}"; do
  echo "Enabling COPR repository: $repo"
  dnf5 copr enable -y "$repo"
done

# Add Qt-coupled Hyprland helpers only when the base image Qt is new enough.
# bazzite-nvidia can lag Fedora's Qt updates, and rpm-ostree cannot layer
# packages that require replacing qt6-qtbase from the base commit.
QT_VERSION=$(rpm -q qt6-qtbase --queryformat '%{VERSION}' 2>/dev/null || echo "unknown")
echo "Detected Qt version: $QT_VERSION"
if [[ "$QT_VERSION" == "unknown" ]] ||
   [[ "$(printf '%s\n' "6.11" "$QT_VERSION" | sort -V | head -n1)" != "6.11" ]]; then
  echo "Qt $QT_VERSION is below 6.11 - using polkit-kde from the base image and skipping hyprland-qt-support"
else
  echo "Using Hyprland Qt support packages"
  hyprland_packages+=(hyprland-qt-support hyprpolkitagent)
fi

echo "Installing Hyprland and dependencies"
rpm-ostree install "${hyprland_packages[@]}"

echo "Installing Lan Mouse"
"${SCRIPT_DIR}/install-lan-mouse.sh"

# NOTE: Plugin build dependencies are NOT installed here due to gcc version conflicts
# with the base image. Instead, users should use the hyprland-build distrobox container.
# Run: ujust setup-hyprland-build create
echo "Skipping plugin build dependencies (use hyprland-build distrobox instead)"

# Install ujust recipe for hyprland plugin building
echo "Installing hyprland-build ujust recipe"
install -Dm644 "${SCRIPT_DIR}/justfiles/60-custom.just" /usr/share/ublue-os/just/60-custom.just
