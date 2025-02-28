#!/bin/bash

set -ouex pipefail

RELEASE="$(rpm -E %fedora)"

echo "Installing Awesome WM"
source ../awesome/build.sh

echo "Removing unprofessional packages"
rpm-ostree override remove steam steam-devices lutris

#echo "Installing Productivity Software"
#wget "https://downloads.1password.com/linux/rpm/stable/x86_64/1password-latest.rpm"
#
#rpm-ostree install ./1password-latest.rpm

