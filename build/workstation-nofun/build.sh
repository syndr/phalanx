#!/bin/bash
# Workstation-specific configuration for Fedora with gaming packages removed

# Unprofessional packages that should be removed
workstation_packages_remove=(
  steam steam-devices lutris
)

set -ouex pipefail

echo "Configuring workstation image"
source ../workstation/build.sh

echo "Removing unprofessional packages"
rpm-ostree override remove "${workstation_packages_remove[@]}"
