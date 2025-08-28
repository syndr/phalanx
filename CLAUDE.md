# Phalanx - Universal Blue OCI Container Image Builder

An opinionated Linux system based upon Fedora Atomic OS and Universal Blue that builds bootable OCI container images for rpm-ostree deployment.

## Project Overview

Phalanx creates custom Fedora-based immutable operating system images using the Universal Blue framework. The project builds four variants:

- **base**: Core system with essential packages (zsh, kitty, neovim, Active Directory integration, KDE add-ons, system utilities)
- **awesome**: Base + Awesome WM desktop environment with custom configuration and dotfiles
- **workstation**: Full development environment with utilities, dotfiles, Docker CE, and 1Password repository
- **workstation-nofun**: Workstation variant (appears in workflows, build script not yet implemented)

All images are built from Bazzite (gaming-focused Universal Blue variant) as the upstream base.

## Repository Structure

```
phalanx/
├── Containerfile             # Unified parameterized container build instructions
├── build/                    # Build configurations for each variant
│   ├── base/
│   │   └── build.sh         # Base package installation script
│   ├── awesome/
│   │   └── build.sh         # Awesome WM setup and dotfiles installation
│   └── workstation/
│       └── build.sh         # Workstation-specific package management
├── .github/workflows/        # GitHub Actions CI/CD workflows
│   ├── build.yml            # Reusable build workflow template
│   ├── build-base.yml       # Base variant build trigger
│   ├── build-awesomewm.yml  # Awesome variant build trigger
│   └── build-workstation.yml # Workstation variant build trigger
├── files/
│   └── logo.png             # Project logo
├── cosign.pub               # Cosign public key for image verification
├── LICENSE                  # Project license
└── README.md                # Project documentation
```

## Build System

### Container Images

The project uses a single unified `Containerfile` with build-time parameterization:

1. **Build Arguments**: 
   - `SOURCE_IMAGE`: Upstream base image (default: "bazzite")
   - `SOURCE_SUFFIX`: Hardware-specific suffixes ("", "nvidia", "asus", etc.)
   - `SOURCE_TAG`: Version tag (default: "latest")
   - `VARIANT`: Build variant to use ("base", "awesome", "workstation")

2. **Base FROM**: `ghcr.io/ublue-os/${SOURCE_IMAGE}${SOURCE_SUFFIX}:${SOURCE_TAG}`

3. **Modifications**: Copy all build scripts and execute the variant-specific script with `ostree container commit`

### Build Scripts

- **base/build.sh**: Installs core packages including:
  - Active Directory integration (adcli, sssd-ad, realmd, samba-common-tools)
  - Shell fundamentals (zsh, kitty, neovim)
  - System utilities (gvfs-smb, btop)
  - KDE add-ons (kvantum, arc-kde-kvantum)
  
- **awesome/build.sh**: 
  - Sources base build
  - Installs Awesome WM with full desktop stack
  - Clones and installs dotfiles from GitHub repositories (maintained as git repo in /etc/skel)
  - Includes window manager utilities (picom, rofi, nitrogen, etc.)
  
- **workstation/build.sh**:
  - Installs development utilities (git-delta, copyq, ranger, kitty, rofi components)
  - Clones and installs dotfiles to /etc/skel (non-git approach)
  - Configures 1Password repository (installation deferred to post-boot)
  - Installs Docker CE full stack (docker-ce, docker-compose, buildx)

### GitHub Actions Workflows

The CI/CD system uses a reusable workflow pattern:

- **build.yml**: Main reusable workflow handling build, push, and signing operations
  - Uses unified Containerfile in repository root
  - Passes VARIANT build arg to select which variant to build
  - Handles container signing with Cosign
  
- **Variant-specific workflows**:
  - `build-base.yml`: Builds base variant
  - `build-awesomewm.yml`: Builds awesome variant  
  - `build-workstation.yml`: Builds workstation and workstation-nofun variants with matrix strategy for NVIDIA support

- **Build triggers**:
  - Daily scheduled builds at 10:05 AM UTC
  - Push to main branch with relevant file changes
  - Pull requests
  - Manual workflow dispatch

### Key Features

- **Immutable OS**: Built on rpm-ostree for atomic updates and rollbacks
- **Container-native**: Images stored in OCI registries, pulled as updates
- **Unified Build System**: Single parameterized Containerfile for all variants
- **Signed Images**: Cosign signatures for supply chain security
- **Automated Builds**: Daily scheduled builds and change-triggered builds
- **Hardware Variants**: Support for NVIDIA, ASUS, Surface, and other hardware configs
- **Repository Management**: Third-party repositories (Docker CE, 1Password) pre-configured
- **Developer Ready**: Workstation variant includes full container development stack

## Development Commands

### Local Building

```bash
# Build base variant locally
podman build -f Containerfile --build-arg VARIANT=base -t phalanx-base .

# Build awesome variant
podman build -f Containerfile --build-arg VARIANT=awesome -t phalanx-awesome .

# Build workstation variant with NVIDIA support
podman build -f Containerfile \
  --build-arg VARIANT=workstation \
  --build-arg SOURCE_SUFFIX=-nvidia \
  -t phalanx-workstation-nvidia .

# Build with custom upstream base
podman build -f Containerfile \
  --build-arg VARIANT=base \
  --build-arg SOURCE_IMAGE=silverblue \
  --build-arg SOURCE_SUFFIX=-nvidia \
  --build-arg SOURCE_TAG=40 \
  -t phalanx-base-custom .
```

### Testing

No specific test frameworks are configured. Manual testing involves:
1. Building images locally
2. Running containers to verify package installation
3. Testing desktop environment functionality (for awesome/workstation variants)

### Deployment

Images are automatically pushed to GitHub Container Registry (GHCR) at:
- `ghcr.io/syndr/phalanx-base:latest`
- `ghcr.io/syndr/phalanx-awesome:latest`
- `ghcr.io/syndr/phalanx-workstation:latest`
- `ghcr.io/syndr/phalanx-workstation-nvidia:latest`
- `ghcr.io/syndr/phalanx-workstation-nofun:latest`
- `ghcr.io/syndr/phalanx-workstation-nofun-nvidia:latest`

### Verification

Verify image signatures using cosign:
```bash
cosign verify --key cosign.pub ghcr.io/syndr/phalanx-base:latest
```

## External Dependencies

- **Dotfiles**: https://github.com/syndr/dotfiles.git (for user shell/app configuration)
- **Awesome Config**: https://github.com/syndr/awesome-wm-config.git (for window manager setup)
- **Universal Blue**: Upstream container images from ghcr.io/ublue-os/
- **GitHub Container Registry**: Image storage and distribution

## Architecture Notes

- Based on Fedora rpm-ostree for immutable OS benefits
- Uses layered container approach for variant management
- Single unified Containerfile with VARIANT build argument for all image types
- Follows Universal Blue best practices for custom image creation
- Implements proper security with signed containers and minimal attack surface
- Designed for enterprise environments with Active Directory integration
- Third-party software (Docker CE, 1Password) handled via repository configuration for clean updates

## Recent Changes

### Unified Build System (2025-08-28)
- Consolidated three separate Containerfiles into single parameterized version
- Added VARIANT build argument to select build variant
- Updated GitHub Actions workflows to use unified Containerfile

### Workstation Enhancements (2025-08-28)
- Added Docker CE installation with full container development stack
- Configured 1Password repository for post-boot installation
- Implemented dotfiles installation for new user accounts
- Added graceful error handling for packages requiring runtime services

### Build Improvements
- Fixed ARG variable expansion in Containerfile (must be declared after FROM)
- Improved error handling for third-party package installations
- Optimized repository configuration for automatic updates