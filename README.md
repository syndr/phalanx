![Phalanx](files/logo.png)

[![build-base](https://github.com/syndr/phalanx/actions/workflows/build-base.yml/badge.svg)](https://github.com/syndr/phalanx/actions/workflows/build-base.yml) [![build-awesomewm](https://github.com/syndr/phalanx/actions/workflows/build-awesomewm.yml/badge.svg)](https://github.com/syndr/phalanx/actions/workflows/build-awesomewm.yml) [![build-hyprland](https://github.com/syndr/phalanx/actions/workflows/build-hyprland.yml/badge.svg)](https://github.com/syndr/phalanx/actions/workflows/build-hyprland.yml) [![build-workstation](https://github.com/syndr/phalanx/actions/workflows/build-workstation.yml/badge.svg)](https://github.com/syndr/phalanx/actions/workflows/build-workstation.yml)

An opinionated, immutable Linux desktop system built on Fedora Atomic OS and [Universal Blue](https://universal-blue.org/), designed for security, reliability, and developer productivity.

## 🎯 Key Features

- **Immutable & Atomic**: Built on rpm-ostree for reliable, atomic system updates with rollback capability
- **Container-Native**: Delivered as OCI container images for consistent deployments
- **Developer-Ready**: Pre-configured development environments with Docker, modern tools, and productivity software
- **Enterprise-Ready**: Active Directory integration and security-focused configuration
- **Hardware Support**: Native support for NVIDIA GPUs and various hardware configurations

## 📦 Available Variants

### `base`
The foundation layer with essential system packages:
- Active Directory integration tools (SSSD, Realmd, Samba)
- Modern shell environment (Zsh, Kitty terminal, Neovim)
- System utilities (btop, gvfs-smb)
- KDE Plasma enhancements (Kvantum themes)

### `awesome`
A keyboard-driven desktop environment built on base:
- AwesomeWM tiling window manager
- Complete desktop stack (Picom compositor, Rofi launcher, Nitrogen wallpaper manager)
- Pre-configured dotfiles and window manager configuration
- Screen management tools (autorandr, redshift)

### `hyprland`
Modern Wayland compositor desktop environment:
- Hyprland dynamic tiling compositor with full Wayland support
- Complete desktop stack (Waybar, SwayNotificationCenter, wlogout)
- Wallpaper and theming (swww, wallust, Kvantum, hyprcursor)
- Screen utilities (hyprlock, hypridle, grim, slurp)
- Plugin build dependencies included for hyprpm customization
- Audio/media tools (pavucontrol, playerctl, mpv, cava)

### `workstation`
Full-featured development environment:
- Container development stack (Docker CE, Docker Compose, Buildx)
- Development utilities (git-delta, ranger file manager)
- Password management (1Password repository configured)
- Productivity tools (CopyQ clipboard manager)
- Custom dotfiles for enhanced workflow

### Hardware Variants
- **Standard**: For most x86_64 systems
- **NVIDIA** (`-nvidia`): Includes proprietary NVIDIA drivers
- **No Fun** (`-nofun`): Workstation variant without gaming packages

## 🚀 Installation

### Prerequisites
- An existing Fedora Atomic Desktop system (Kinoite, Silverblue, Bazzite, etc.)
- Active internet connection for downloading container images

### Installation Steps

Phalanx installation is a two-step process for security verification:

#### Step 1: Initial Rebase (Unsigned)
Choose your desired variant and rebase to the unsigned image:

```bash
# For base variant
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/syndr/phalanx-base:latest

# For awesome variant
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/syndr/phalanx-awesome:latest

# For hyprland variant
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/syndr/phalanx-hyprland:latest

# For hyprland with NVIDIA
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/syndr/phalanx-hyprland-nvidia:latest

# For workstation variant
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/syndr/phalanx-workstation:latest

# For workstation with NVIDIA
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/syndr/phalanx-workstation-nvidia:latest
```

Reboot your system:
```bash
systemctl reboot
```

#### Step 2: Switch to Signed Image
After rebooting, switch to the signed image for verified updates:

```bash
# Replace 'workstation' with your chosen variant
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/syndr/phalanx-workstation:latest
```

Reboot again to complete the installation:
```bash
systemctl reboot
```

### Post-Installation

#### For Workstation Variant
After installation, you can install additional pre-configured software:

```bash
# Install 1Password (repository pre-configured)
rpm-ostree install 1password
systemctl reboot

# Enable Docker service
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
```

## 🔧 Building Locally

Build your own custom images using Podman or Docker:

```bash
# Clone the repository
git clone https://github.com/syndr/phalanx.git
cd phalanx

# Build a specific variant
podman build -f Containerfile --build-arg VARIANT=workstation -t my-phalanx .

# Build with NVIDIA support
podman build -f Containerfile \
  --build-arg VARIANT=workstation \
  --build-arg SOURCE_SUFFIX=-nvidia \
  -t my-phalanx-nvidia .
```

## 🔐 Security

All images are signed with Cosign for supply chain security. Verify signatures using:

```bash
cosign verify --key cosign.pub ghcr.io/syndr/phalanx-workstation:latest
```

## 📖 Documentation

For detailed information about the project architecture, build system, and customization options, see [CLAUDE.md](CLAUDE.md).

## 🤝 Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.

## 📄 License

This project is open source and available under the [LICENSE](LICENSE) file.

## 🙏 Acknowledgments

Built on the excellent work of:
- [Universal Blue](https://universal-blue.org/) - The foundation for custom Fedora Atomic images
- [Bazzite](https://bazzite.gg/) - Gaming-focused Universal Blue variant used as our base
- [Fedora Project](https://fedoraproject.org/) - The upstream distribution

---

<p align="center">
  <i>Phalanx: Assimilate into the future experience</i>
</p>
