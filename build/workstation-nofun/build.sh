#!/bin/bash

set -ouex pipefail

echo "Configuring workstation image"
source ../workstation/build.sh

echo "Removing unprofessional packages"
rpm-ostree override remove steam steam-devices steam-device-rules lutris

