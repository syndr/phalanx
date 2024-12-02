#!/bin/bash

set -ouex pipefail

RELEASE="$(rpm -E %fedora)"


### Install packages

rpm-ostree install neovim zsh \
  adcli oddjob oddjob-mkhomedir sssd-ad realmd samba-common-tools

# Install Awesome WM
rpm-ostree install plasma-workspace-x11 awesome

