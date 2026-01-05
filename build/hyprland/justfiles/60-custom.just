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

    # Build dependencies from Fedora repos (installed during distrobox creation)
    FEDORA_BUILD_PACKAGES="meson cmake gcc-c++ ninja-build git cpio"
    FEDORA_BUILD_PACKAGES+=" wayland-devel wayland-protocols-devel"
    FEDORA_BUILD_PACKAGES+=" libX11-devel libxcb-devel libxkbcommon-devel libXcursor-devel libinput-devel"
    FEDORA_BUILD_PACKAGES+=" xcb-util-wm-devel xcb-util-errors-devel"
    FEDORA_BUILD_PACKAGES+=" re2-devel libuuid-devel tomlplusplus-devel"
    FEDORA_BUILD_PACKAGES+=" pixman-devel cairo-devel pango-devel muParser-devel"
    FEDORA_BUILD_PACKAGES+=" mesa-libGL-devel mesa-libGLES-devel mesa-libEGL-devel mesa-libgbm-devel"

    # Hyprland packages from COPR repos (installed after COPR is enabled)
    COPR_PACKAGES="hyprland hyprutils hyprgraphics hyprlang aquamarine"
    COPR_PACKAGES+=" hyprwayland-scanner-devel hyprlang-devel hyprcursor-devel"
    COPR_PACKAGES+=" hyprutils-devel hyprgraphics-devel aquamarine-devel hyprwire-devel"

    case "{{ ACTION }}" in
        create)
            if distrobox list | grep -q "^${CONTAINER_NAME}"; then
                echo "Container already exists. Use 'ujust setup-hyprland-build enter' or 'ujust setup-hyprland-build remove'"
                exit 1
            fi

            echo "Creating hyprland-build distrobox with Fedora ${FEDORA_VERSION}..."
            distrobox create --name "$CONTAINER_NAME" --image "$IMAGE" --yes \
                --volume "/home/linuxbrew:/home/linuxbrew:ro" \
                --additional-packages "dnf-plugins-core $FEDORA_BUILD_PACKAGES"

            # Enable COPR repos and install hyprland packages
            echo "Enabling COPR repositories..."
            for repo in "${COPR_REPOS[@]}"; do
                echo "  Enabling: $repo"
                distrobox enter --no-workdir "$CONTAINER_NAME" -- sudo dnf copr enable -y "$repo"
            done

            echo "Installing Hyprland packages from COPR..."
            distrobox enter --no-workdir "$CONTAINER_NAME" -- sudo dnf install -y --skip-unavailable $COPR_PACKAGES

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
        init)
            # Import host's hyprpm config into container
            # Copies state.toml files so container knows about existing repos
            echo "Importing host's hyprpm config into container..."
            USERNAME=$(whoami)
            HOST_CACHE="/var/cache/hyprpm/${USERNAME}"
            CONTAINER_CACHE="/var/cache/hyprpm/${USERNAME}"

            # Check if host has hyprpm cache
            if ! test -d "$HOST_CACHE"; then
                echo "No hyprpm cache found on host at $HOST_CACHE"
                exit 1
            fi

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

            # Create temp directory with state files only (no .so files needed)
            rm -rf /tmp/hyprpm-init
            mkdir -p /tmp/hyprpm-init

            # Copy global state if exists
            if test -f "$HOST_CACHE/state.toml"; then
                cp "$HOST_CACHE/state.toml" /tmp/hyprpm-init/
            fi

            # Copy plugin repo configs (state.toml files, not .so files)
            PLUGINS=""
            for plugin_dir in "$HOST_CACHE"/*/; do
                plugin_name=$(basename "$plugin_dir")
                if test "$plugin_name" = "headersRoot"; then continue; fi
                if test -f "$plugin_dir/state.toml"; then
                    mkdir -p "/tmp/hyprpm-init/$plugin_name"
                    cp "$plugin_dir/state.toml" "/tmp/hyprpm-init/$plugin_name/"
                    PLUGINS="$PLUGINS $plugin_name"
                fi
            done

            if test -z "$PLUGINS"; then
                echo "No plugin configs found on host."
                rm -rf /tmp/hyprpm-init
                exit 1
            fi

            # Create cache directory in container and copy configs
            echo "Creating container cache directory..."
            podman exec "$CONTAINER_NAME" sudo mkdir -p "$CONTAINER_CACHE"

            echo "Copying plugin configs to container..."
            podman cp "/tmp/hyprpm-init/." "${CONTAINER_NAME}:${CONTAINER_CACHE}/"

            # Fix ownership in container (hyprpm expects root:root)
            podman exec "$CONTAINER_NAME" sudo chown -R root:root "$CONTAINER_CACHE"

            rm -rf /tmp/hyprpm-init

            echo ""
            echo "Done! Imported configs for:$PLUGINS"
            echo ""
            echo "Now enter the container and run 'hyprpm update' to rebuild all plugins:"
            echo "  ujust setup-hyprland-build enter"
            echo "  hyprpm update"
            ;;
        sync|sync-force)
            # Sync hyprpm cache (headers, state, plugins) from container to host
            FORCE_MODE=false
            if test "{{ ACTION }}" = "sync-force"; then
                FORCE_MODE=true
                echo "Force mode: Will overwrite existing files"
                echo ""
            fi

            echo "Syncing hyprpm cache from container to host..."
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

            # Check if container has hyprpm cache
            if ! podman exec "$CONTAINER_NAME" test -d "$CONTAINER_CACHE"; then
                echo "No hyprpm cache found in container. Run 'hyprpm update' first."
                exit 1
            fi

            # Copy entire cache from container to temp location
            echo "Copying cache from container..."
            rm -rf /tmp/hyprpm-sync
            mkdir -p /tmp/hyprpm-sync
            podman cp "${CONTAINER_NAME}:${CONTAINER_CACHE}/." "/tmp/hyprpm-sync/"

            # Ensure host cache directory exists
            sudo mkdir -p "$HOST_CACHE"

            # Sync headers and global state (always update these)
            if test -d /tmp/hyprpm-sync/headersRoot; then
                echo "  Syncing headers..."
                sudo rm -rf "$HOST_CACHE/headersRoot"
                sudo cp -r /tmp/hyprpm-sync/headersRoot "$HOST_CACHE/"
                # Strip Requires line from hyprland.pc - host doesn't have -devel packages
                # but hyprpm just needs include paths, not dependency resolution
                sudo sed -i '/^Requires:/d' "$HOST_CACHE/headersRoot/share/pkgconfig/hyprland.pc"
            fi
            if test -f /tmp/hyprpm-sync/state.toml; then
                echo "  Syncing global state..."
                sudo cp /tmp/hyprpm-sync/state.toml "$HOST_CACHE/"
            fi

            # Sync plugin directories
            SKIPPED=""
            ADDED=""
            UPDATED=""
            for plugin_dir in /tmp/hyprpm-sync/*/; do
                plugin_name=$(basename "$plugin_dir")
                # Skip headers (already handled above)
                if test "$plugin_name" = "headersRoot"; then continue; fi

                if test -d "$HOST_CACHE/$plugin_name"; then
                    if $FORCE_MODE; then
                        echo "  Updating plugin: $plugin_name"
                        sudo rm -rf "$HOST_CACHE/$plugin_name"
                        sudo cp -r "$plugin_dir" "$HOST_CACHE/"
                        UPDATED="$UPDATED $plugin_name"
                    else
                        echo "  Skipping existing: $plugin_name (use sync-force to update)"
                        SKIPPED="$SKIPPED $plugin_name"
                    fi
                else
                    echo "  Adding plugin: $plugin_name"
                    sudo cp -r "$plugin_dir" "$HOST_CACHE/"
                    ADDED="$ADDED $plugin_name"
                fi
            done

            # Set proper ownership (hyprpm expects root:root)
            sudo chown -R root:root "$HOST_CACHE"

            rm -rf /tmp/hyprpm-sync

            echo ""
            echo "Done! Cache synced to ${HOST_CACHE}"
            if test -n "$ADDED"; then
                echo "  New plugins:$ADDED"
                echo "  Enable with: hyprpm enable <plugin-name>"
            fi
            if test -n "$UPDATED"; then
                echo "  Updated plugins:$UPDATED"
            fi
            if test -n "$SKIPPED"; then
                echo "  Skipped (use sync-force to update):$SKIPPED"
            fi
            echo ""
            echo "Run 'hyprpm reload' to load plugins."
            ;;
        *)
            echo "Hyprland Build Environment for plugin compilation"
            echo ""
            echo "Usage: ujust setup-hyprland-build <action>"
            echo ""
            echo "Actions:"
            echo "  create      - Create the build container (Fedora ${FEDORA_VERSION})"
            echo "  enter       - Enter the build container"
            echo "  init        - Import host's plugin configs into container"
            echo "  sync        - Copy headers, state, and NEW plugins to host"
            echo "  sync-force  - Copy everything, overwriting existing plugins"
            echo "  remove      - Remove the build container"
            echo ""
            echo "Workflow for new plugins:"
            echo "  1. ujust setup-hyprland-build create"
            echo "  2. ujust setup-hyprland-build enter"
            echo "  3. hyprpm update && hyprpm add <plugin-url>"
            echo "  4. exit"
            echo "  5. ujust setup-hyprland-build sync"
            echo "  6. hyprpm enable <plugin> && hyprpm reload"
            echo ""
            echo "Workflow for rebuilding (after Hyprland update):"
            echo "  1. ujust setup-hyprland-build init   # import existing plugins"
            echo "  2. ujust setup-hyprland-build enter"
            echo "  3. hyprpm update                     # rebuild all"
            echo "  4. exit"
            echo "  5. ujust setup-hyprland-build sync-force"
            echo "  6. hyprpm reload"
            ;;
    esac
