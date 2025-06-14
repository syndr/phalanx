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

# Install Awesome WM
#  - include dependencies for default config
echo "Installing Awesome WM"
rpm-ostree install plasma-workspace-x11 awesome picom rofi-wayland rofi-themes rofi-themes-base16 ranger kitty \
  redshift-gtk copyq flameshot autorandr nitrogen barrier \
  xscreensaver-base xscreensaver-extras xscreensaver-gl-base xscreensaver-gl-extras

echo "Configuring Awesome WM"
# Configure Awesome WM
mkdir -p /etc/skel/.config
git clone --depth 1 --recurse-submodules --shallow-submodules https://github.com/syndr/awesome-wm-config.git /etc/skel/.config/awesome

