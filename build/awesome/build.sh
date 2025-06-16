#!/bin/bash
# Configuration for Awesome WM desktop environment

# Package list for Awesome WM configuration
awesome_packages=(
  # Base packages
  awesome picom

  # Screen management and utilities
  xscreensaver-base xscreensaver-extras xscreensaver-gl-base xscreensaver-gl-extras
  autorandr nitrogen barrier

  # User utilities
  flameshot copyq ranger kitty redshift-gtk
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

# Install Awesome WM
#  - include dependencies for default config
echo "Installing Awesome WM packages"
rpm-ostree install "${awesome_packages[@]}"

echo "Configuring Awesome WM"
# Configure Awesome WM
mkdir -p /etc/skel/.config
git clone --depth 1 --recurse-submodules --shallow-submodules https://github.com/syndr/awesome-wm-config.git /etc/skel/.config/awesome

