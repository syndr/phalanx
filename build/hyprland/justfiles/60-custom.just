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

    # COPR repositories for hyprland packages (same as base image)
    COPR_REPOS=(
        "lionheartp/Hyprland"
        "alebastr/sway-extras"
    )

    # Core hyprland packages needed for hyprpm
    HYPRLAND_PACKAGES="hyprland hyprutils hyprgraphics hyprlang aquamarine"

    # Build dependencies for hyprpm plugins
    BUILD_PACKAGES="meson cmake gcc-c++ ninja-build git cpio"
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
                --volume "/home/linuxbrew:/home/linuxbrew:ro" \
                --additional-packages "dnf-plugins-core $BUILD_PACKAGES"

            # Enable COPR repos and install hyprland packages
            echo "Enabling COPR repositories..."
            for repo in "${COPR_REPOS[@]}"; do
                echo "  Enabling: $repo"
                distrobox enter --no-workdir "$CONTAINER_NAME" -- sudo dnf copr enable -y "$repo"
            done

            echo "Installing hyprland packages..."
            distrobox enter --no-workdir "$CONTAINER_NAME" -- sudo dnf install -y --skip-unavailable $HYPRLAND_PACKAGES

            # Create /var/home symlink for Fedora Atomic compatibility
            # hyprpm stores state with absolute paths from host (/var/home/...)
            echo "Setting up Fedora Atomic home directory compatibility..."
            distrobox enter --no-workdir "$CONTAINER_NAME" -- sudo mkdir -p /var
            distrobox enter --no-workdir "$CONTAINER_NAME" -- sudo ln -sf /home /var/home

            # Set up Homebrew PATH so host's homebrew tools work in container
            echo "Setting up Homebrew environment..."
            distrobox enter --no-workdir "$CONTAINER_NAME" -- sudo bash -c \
                'printf "%s\n" "# Homebrew environment for distrobox" "test -d /home/linuxbrew/.linuxbrew && eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\"" > /etc/profile.d/homebrew.sh && chmod +x /etc/profile.d/homebrew.sh'

            echo "Done! Enter with: ujust setup-hyprland-build enter"
            ;;
        enter)
            distrobox enter "$CONTAINER_NAME"
            ;;
        remove)
            distrobox rm "$CONTAINER_NAME" --force
            ;;
        sync|sync-force)
            # Sync plugins built in container to host's hyprpm cache
            FORCE_MODE=false
            if test "{{ ACTION }}" = "sync-force"; then
                FORCE_MODE=true
                echo "⚠️  Force mode: Will overwrite existing plugins"
                echo "   Make sure Hyprland is not running or plugins are unloaded!"
                echo ""
                echo "Currently loaded plugins on host:"
                hyprpm list 2>/dev/null | grep -E "(Plugin|enabled: true)" | head -20 || echo "   (could not get plugin list)"
                echo ""
            fi

            echo "Syncing hyprpm plugins from container to host..."
            USERNAME=$(whoami)
            CONTAINER_CACHE="/var/cache/hyprpm/${USERNAME}"
            HOST_CACHE="/var/cache/hyprpm/${USERNAME}"

            # Check if container exists
            if ! podman container exists "$CONTAINER_NAME"; then
                echo "Error: Container not found. Create it first with: ujust setup-hyprland-build create"
                exit 1
            fi

            # Start container if not running
            if ! podman container inspect "$CONTAINER_NAME" --format "{{{{.State.Running}}}}" 2>/dev/null | grep -q "true"; then
                echo "Starting container..."
                podman start "$CONTAINER_NAME" > /dev/null
            fi

            # Check if container has any plugins
            if ! podman exec "$CONTAINER_NAME" test -d "$CONTAINER_CACHE"; then
                echo "No plugins found in container. Build some first with: hyprpm add <url>"
                exit 1
            fi

            # Copy plugins from container to temp location
            echo "Copying plugins from container..."
            rm -rf /tmp/hyprpm-sync
            mkdir -p /tmp/hyprpm-sync
            podman cp "${CONTAINER_NAME}:${CONTAINER_CACHE}/." "/tmp/hyprpm-sync/"
            sudo mkdir -p "$HOST_CACHE"

            # Sync each plugin directory individually (skip config files)
            SKIPPED=""
            ADDED=""
            UPDATED=""
            for plugin_dir in /tmp/hyprpm-sync/*/; do
                plugin_name=$(basename "$plugin_dir")
                # Skip non-plugin directories and config files
                if test "$plugin_name" = "headersRoot"; then continue; fi

                if test -d "$HOST_CACHE/$plugin_name"; then
                    if $FORCE_MODE; then
                        echo "  Updating: $plugin_name"
                        # Only copy .so files, preserve host's state.toml
                        for so_file in "$plugin_dir"*.so; do
                            if test -f "$so_file"; then
                                sudo cp "$so_file" "$HOST_CACHE/$plugin_name/"
                            fi
                        done
                        UPDATED="$UPDATED $plugin_name"
                    else
                        echo "  Skipping existing: $plugin_name (use sync-force to update)"
                        SKIPPED="$SKIPPED $plugin_name"
                    fi
                else
                    echo "  Adding new: $plugin_name"
                    sudo cp -r "$plugin_dir" "$HOST_CACHE/"
                    ADDED="$ADDED $plugin_name"
                fi
            done

            rm -rf /tmp/hyprpm-sync

            echo ""
            echo "Done! Plugins synced to ${HOST_CACHE}"
            if test -n "$ADDED"; then
                echo "  New plugins added:$ADDED"
                echo "  Enable them with: hyprpm enable <plugin-name>"
            fi
            if test -n "$UPDATED"; then
                echo "  Plugins updated:$UPDATED"
                echo "  Reload with: hyprpm reload"
            fi
            if test -n "$SKIPPED"; then
                echo "  Skipped (already exist):$SKIPPED"
                echo "  To update these, use: ujust setup-hyprland-build sync-force"
            fi
            ;;
        *)
            echo "Hyprland Build Environment for plugin compilation"
            echo ""
            echo "Usage: ujust setup-hyprland-build <action>"
            echo ""
            echo "Actions:"
            echo "  create      - Create the build container (Fedora ${FEDORA_VERSION})"
            echo "  enter       - Enter the build container"
            echo "  sync        - Copy NEW plugins from container to host (safe)"
            echo "  sync-force  - Update ALL plugins (overwrites existing .so files)"
            echo "  remove      - Remove the build container"
            echo ""
            echo "Workflow for new plugins:"
            echo "  1. ujust setup-hyprland-build create"
            echo "  2. ujust setup-hyprland-build enter"
            echo "  3. hyprpm add <plugin-url>  # inside container"
            echo "  4. exit"
            echo "  5. ujust setup-hyprland-build sync"
            echo "  6. hyprpm enable <plugin-name>"
            echo ""
            echo "Workflow for updating plugins (after Hyprland update):"
            echo "  1. ujust setup-hyprland-build enter"
            echo "  2. hyprpm update  # inside container"
            echo "  3. exit"
            echo "  4. ujust setup-hyprland-build sync-force"
            echo "  5. hyprpm reload"
            ;;
    esac
