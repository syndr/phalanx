# Phalanx custom ujust recipes

# Setup the hyprland-build distrobox for plugin compilation
[group('Phalanx')]
setup-hyprland-build ACTION="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    set -euo pipefail

    CONTAINER_NAME="hyprland-build"

    # Get Fedora version from host OS
    FEDORA_VERSION=$(grep -oP '^VERSION_ID=\K\d+' /etc/os-release)
    IMAGE="registry.fedoraproject.org/fedora:${FEDORA_VERSION}"

    # Build dependencies for hyprpm plugins
    BUILD_PACKAGES="meson cmake gcc-c++ ninja-build git"
    BUILD_PACKAGES+=" hyprwayland-scanner-devel hyprlang-devel hyprcursor-devel"
    BUILD_PACKAGES+=" hyprutils-devel hyprgraphics-devel"
    BUILD_PACKAGES+=" wayland-devel wayland-protocols-devel"
    BUILD_PACKAGES+=" libX11-devel aquamarine-devel"
    BUILD_PACKAGES+=" libxcb-devel libxkbcommon-devel libXcursor-devel libinput-devel"
    BUILD_PACKAGES+=" xcb-util-wm-devel xcb-util-errors-devel"
    BUILD_PACKAGES+=" re2-devel libuuid-devel tomlplusplus-devel"
    BUILD_PACKAGES+=" pixman-devel cairo-devel pango-devel"
    BUILD_PACKAGES+=" mesa-libGL-devel mesa-libGLES-devel mesa-libEGL-devel mesa-libgbm-devel"

    case "{{ ACTION }}" in
        create)
            if distrobox list | grep -q "^${CONTAINER_NAME}"; then
                echo "Container already exists. Use 'ujust setup-hyprland-build enter' or 'ujust setup-hyprland-build remove'"
                exit 1
            fi
            echo "Creating hyprland-build distrobox with Fedora ${FEDORA_VERSION}..."
            distrobox create --name "$CONTAINER_NAME" --image "$IMAGE" --yes \
                --additional-packages "$BUILD_PACKAGES"
            echo "Done! Enter with: ujust setup-hyprland-build enter"
            ;;
        enter)
            distrobox enter "$CONTAINER_NAME"
            ;;
        remove)
            distrobox rm "$CONTAINER_NAME" --force
            ;;
        *)
            echo "Hyprland Build Environment for plugin compilation"
            echo ""
            echo "Usage: ujust setup-hyprland-build <action>"
            echo ""
            echo "Actions:"
            echo "  create  - Create the build container (Fedora ${FEDORA_VERSION})"
            echo "  enter   - Enter the build container"
            echo "  remove  - Remove the build container"
            ;;
    esac
