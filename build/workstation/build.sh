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

echo "Installing Hyprland"
source ../hyprland/build.sh

echo "Installing Utilities"
rpm-ostree install git-delta copyq ranger kitty rofi-wayland rofi-themes rofi-themes-base16

echo "Installing dotfiles"
# Clone dotfiles to temporary directory
git clone --depth 1 --recurse-submodules --shallow-submodules https://github.com/syndr/dotfiles.git /tmp/dotfiles
# Copy files to /etc/skel (excluding .git directory)
cd /tmp/dotfiles
# Remove existing files that might conflict
rm -f /etc/skel/.zshrc
# Copy all dotfiles except .git directory
find . -mindepth 1 -maxdepth 1 ! -name '.git' -exec cp -r {} /etc/skel/ \;
# Clean up temporary directory
rm -rf /tmp/dotfiles

echo "Adding 1Password repository"
# Add 1Password official RPM repository
cat > /etc/yum.repos.d/1password.repo << 'EOF'
[1password]
name=1Password Stable Channel
baseurl=https://downloads.1password.com/linux/rpm/stable/$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://downloads.1password.com/linux/keys/1password.asc
EOF

echo "Installing 1Password"
# Try to install 1Password from repository
# Note: This may fail in container builds due to post-install scripts
rpm-ostree install 1password || {
    echo "Warning: 1Password installation failed (expected in container build)"
    echo "1Password repository has been configured and can be installed after first boot"
}

echo "Adding Docker CE repository"
curl -fsSL https://download.docker.com/linux/fedora/docker-ce.repo -o /etc/yum.repos.d/docker-ce.repo

echo "Installing Docker CE"
rpm-ostree install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
