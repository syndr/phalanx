#!/bin/bash
# Workstation-specific configuration for Fedora

# Package list for workstation configuration
workstation_packages=(
  # Git and diff tools
  git-delta
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

echo "Installing Hyprland"
source ../hyprland/build.sh

echo "Installing Workstation packages"
rpm-ostree install "${workstation_packages[@]}"

echo "Creating 1Password CLI sysusers configuration"
# Pre-create the onepassword-cli group with a GID of 11005 (>= 1000)
# This ensures that when the layered 1password-cli package is installed/updated on the host,
# its files are owned by a valid user-level GID rather than a system GID under 1000.
mkdir -p /usr/lib/sysusers.d
echo "g onepassword-cli 11005 -" > /usr/lib/sysusers.d/10-1password-cli.conf

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
