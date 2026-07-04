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

    # Helper function: Check if container exists
    container_exists() {
        podman container exists "$CONTAINER_NAME"
    }

    # Helper function: Get host and container Hyprland versions
    get_hyprland_versions() {
        # Get host version via hyprctl (running compositor) with fallback to rpm
        if command -v hyprctl &>/dev/null && hyprctl version -j &>/dev/null; then
            HOST_VERSION=$(hyprctl version -j 2>/dev/null | jq -r '.version' 2>/dev/null)
        fi
        if [[ -z "$HOST_VERSION" ]] || [[ "$HOST_VERSION" == "null" ]]; then
            HOST_VERSION=$(rpm -q --qf '%{VERSION}' hyprland 2>/dev/null || echo "unknown")
        fi

        # Get container version via rpm query (installed package)
        if container_exists; then
            # Ensure container is running for version check
            if ! podman container inspect "$CONTAINER_NAME" --format "{{{{.State.Running}}}}" 2>/dev/null | grep -q "true"; then
                podman start "$CONTAINER_NAME" > /dev/null 2>&1
            fi
            CONTAINER_VERSION=$(podman exec "$CONTAINER_NAME" rpm -q --qf '%{VERSION}' hyprland 2>/dev/null || echo "unknown")
        else
            CONTAINER_VERSION="N/A"
        fi
    }

    # Helper function: Compare host and container versions
    # Returns: 0 = match, 1 = mismatch, 2 = unknown (can't compare)
    compare_versions() {
        if [[ "$HOST_VERSION" == "unknown" ]] || [[ "$CONTAINER_VERSION" == "unknown" ]] || [[ "$CONTAINER_VERSION" == "N/A" ]]; then
            return 2  # Unknown - can't compare
        elif [[ "$HOST_VERSION" == "$CONTAINER_VERSION" ]]; then
            return 0  # Match
        else
            return 1  # Mismatch
        fi
    }

    # Helper function: Display version status
    show_version_status() {
        get_hyprland_versions
        echo "Hyprland Versions:"
        echo "  Host:      ${HOST_VERSION}"
        echo "  Container: ${CONTAINER_VERSION}"

        local result=0
        compare_versions || result=$?
        if [[ $result -eq 0 ]]; then
            echo "  Status:    IN SYNC"
        elif [[ $result -eq 1 ]]; then
            echo "  Status:    MISMATCH - rebuild recommended"
        else
            echo "  Status:    UNKNOWN - unable to compare"
        fi
    }

    # Helper function: Ensure container is running
    ensure_container_running() {
        if ! container_exists; then
            echo "Error: Container not found. Create it first with: ujust setup-hyprland-build create"
            exit 1
        fi
        if ! podman container inspect "$CONTAINER_NAME" --format "{{{{.State.Running}}}}" 2>/dev/null | grep -q "true"; then
            echo "Starting container..."
            podman start "$CONTAINER_NAME" > /dev/null
        fi
    }

    # Helper function: Import host's hyprpm config into container
    import_plugin_configs() {
        echo "Importing host's hyprpm config into container..."
        local USERNAME=$(whoami)
        local HOST_CACHE="/var/cache/hyprpm/${USERNAME}"
        local CONTAINER_CACHE="/var/cache/hyprpm/${USERNAME}"

        # Check if host has hyprpm cache
        if ! test -d "$HOST_CACHE"; then
            echo "No hyprpm cache found on host at $HOST_CACHE"
            return 1
        fi

        # Create temp directory with state files only (no .so files needed)
        rm -rf /tmp/hyprpm-init
        mkdir -p /tmp/hyprpm-init

        # Copy global state if exists
        if test -f "$HOST_CACHE/state.toml"; then
            cp "$HOST_CACHE/state.toml" /tmp/hyprpm-init/
        fi

        # Copy plugin repo configs (state.toml files, not .so files)
        local PLUGINS=""
        for plugin_dir in "$HOST_CACHE"/*/; do
            local plugin_name=$(basename "$plugin_dir")
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
            return 1
        fi

        # Create cache directory in container and copy configs
        echo "Creating container cache directory..."
        podman exec "$CONTAINER_NAME" sudo mkdir -p "$CONTAINER_CACHE"

        echo "Copying plugin configs to container..."
        podman cp "/tmp/hyprpm-init/." "${CONTAINER_NAME}:${CONTAINER_CACHE}/"

        # Fix ownership in container (hyprpm expects root:root)
        podman exec "$CONTAINER_NAME" sudo chown -R root:root "$CONTAINER_CACHE"

        rm -rf /tmp/hyprpm-init

        echo "Imported configs for:$PLUGINS"
    }

    # Helper function: Sync plugins from container to host
    sync_plugins() {
        echo "Syncing hyprpm cache from container to host..."
        local USERNAME=$(whoami)
        local CONTAINER_CACHE="/var/cache/hyprpm/${USERNAME}"
        local HOST_CACHE="/var/cache/hyprpm/${USERNAME}"

        # Check if container has hyprpm cache
        if ! podman exec "$CONTAINER_NAME" test -d "$CONTAINER_CACHE"; then
            echo "No hyprpm cache found in container. Run 'hyprpm update' first."
            return 1
        fi

        # Copy entire cache from container to temp location
        echo "Copying cache from container..."
        rm -rf /tmp/hyprpm-sync
        mkdir -p /tmp/hyprpm-sync
        podman cp "${CONTAINER_NAME}:${CONTAINER_CACHE}/." "/tmp/hyprpm-sync/"

        # Ensure host cache directory exists
        sudo mkdir -p "$HOST_CACHE"

        # Sync headers and global state
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

        # Sync plugin directories (always overwrite)
        local SYNCED=""
        for plugin_dir in /tmp/hyprpm-sync/*/; do
            local plugin_name=$(basename "$plugin_dir")
            # Skip headers (already handled above)
            if test "$plugin_name" = "headersRoot"; then continue; fi

            echo "  Syncing plugin: $plugin_name"
            sudo rm -rf "$HOST_CACHE/$plugin_name"
            sudo cp -r "$plugin_dir" "$HOST_CACHE/"
            SYNCED="$SYNCED $plugin_name"
        done

        # Set proper ownership (hyprpm expects root:root)
        sudo chown -R root:root "$HOST_CACHE"

        rm -rf /tmp/hyprpm-sync

        echo ""
        echo "Done! Cache synced to ${HOST_CACHE}"
        if test -n "$SYNCED"; then
            echo "  Synced plugins:$SYNCED"
        fi
    }

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

            echo "Done! Run 'ujust setup-hyprland-build rebuild' to sync plugins."
            ;;
        enter)
            distrobox enter "$CONTAINER_NAME"
            ;;
        remove)
            distrobox rm "$CONTAINER_NAME" --force
            ;;
        update)
            # Update container packages to match host Hyprland version
            echo "Updating container packages..."
            ensure_container_running

            # Get versions before update
            get_hyprland_versions
            BEFORE_VERSION="$CONTAINER_VERSION"
            echo "  Host version:      ${HOST_VERSION}"
            echo "  Container version: ${BEFORE_VERSION}"
            echo ""

            echo "Updating COPR packages in container..."
            distrobox enter --no-workdir "$CONTAINER_NAME" -- sudo dnf update -y --refresh $COPR_PACKAGES

            # Get version after update
            CONTAINER_VERSION=$(podman exec "$CONTAINER_NAME" rpm -q --qf '%{VERSION}' hyprland 2>/dev/null || echo "unknown")

            echo ""
            if [[ "$BEFORE_VERSION" != "$CONTAINER_VERSION" ]]; then
                echo "Container version: ${BEFORE_VERSION} → ${CONTAINER_VERSION}"
            else
                echo "Container version: ${CONTAINER_VERSION} (no change)"
            fi
            echo "Done!"
            ;;
        sync)
            # Sync hyprpm cache (headers, state, plugins) from container to host
            ensure_container_running
            sync_plugins

            echo ""
            echo "Run 'hyprpm reload' to load plugins."
            ;;
        status)
            # Show host and container Hyprland versions
            show_version_status
            ;;
        rebuild)
            # Full automated workflow: update → import configs → hyprpm update → sync → reload
            echo "=== Hyprland Plugin Rebuild (Automated) ==="
            echo ""
            ensure_container_running

            # Show version status
            get_hyprland_versions
            echo "Hyprland Versions:"
            echo "  Host:      ${HOST_VERSION}"
            echo "  Container: ${CONTAINER_VERSION}"

            # Check if versions already match and prompt user
            version_result=0
            compare_versions || version_result=$?
            if [[ $version_result -eq 0 ]]; then
                echo "  Status:    IN SYNC"
                echo ""
                echo "Versions already match. Rebuild anyway? [y/N]"
                read -r CONFIRM
                if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
                    echo "Rebuild cancelled."
                    exit 0
                fi
            else
                echo "  Status:    MISMATCH"
            fi
            echo ""

            BEFORE_VERSION="$CONTAINER_VERSION"

            # Step 1: Update container packages
            echo "Step 1/5: Updating container packages..."
            distrobox enter --no-workdir "$CONTAINER_NAME" -- sudo dnf update -y --refresh $COPR_PACKAGES

            # Get version after update
            CONTAINER_VERSION=$(podman exec "$CONTAINER_NAME" rpm -q --qf '%{VERSION}' hyprland 2>/dev/null || echo "unknown")
            if [[ "$BEFORE_VERSION" != "$CONTAINER_VERSION" ]]; then
                echo "  Container version: ${BEFORE_VERSION} → ${CONTAINER_VERSION}"
            fi
            echo ""

            # Step 2: Import host plugin configs
            echo "Step 2/5: Importing plugin configs..."
            import_plugin_configs || { echo "Warning: Could not import configs, continuing anyway..."; }
            echo ""

            # Step 3: Run hyprpm update in container
            echo "Step 3/5: Running hyprpm update in container..."
            distrobox enter --no-workdir "$CONTAINER_NAME" -- hyprpm update
            echo ""

            # Step 4: Sync plugins back to host
            echo "Step 4/5: Syncing plugins to host..."
            sync_plugins
            echo ""

            # Step 5: Reload plugins on host
            echo "Step 5/5: Reloading plugins..."
            hyprpm reload

            echo ""
            echo "=== Rebuild complete! ==="
            ;;
        rebuild-interactive)
            # Interactive workflow: update → import configs → shell → sync → reload
            echo "=== Hyprland Plugin Rebuild (Interactive) ==="
            echo ""
            ensure_container_running

            # Step 1: Update container packages
            echo "Step 1/4: Updating container packages..."
            distrobox enter --no-workdir "$CONTAINER_NAME" -- sudo dnf update -y --refresh $COPR_PACKAGES
            echo ""

            # Step 2: Import host plugin configs
            echo "Step 2/4: Importing plugin configs..."
            import_plugin_configs || { echo "Warning: Could not import configs, continuing anyway..."; }
            echo ""

            # Step 3: Drop into container shell
            echo "Step 3/4: Entering container for manual work..."
            echo "  Run 'hyprpm update' and any other commands, then 'exit' when done."
            echo ""
            distrobox enter "$CONTAINER_NAME"
            echo ""

            # Step 4: Sync plugins back to host (after user exits)
            echo "Step 4/4: Syncing plugins to host..."
            sync_plugins
            echo ""

            # Reload plugins on host
            echo "Reloading plugins..."
            hyprpm reload

            echo ""
            echo "=== Rebuild complete! ==="
            ;;
        *)
            echo "Hyprland Build Environment for plugin compilation"
            echo ""
            echo "Usage: ujust setup-hyprland-build <action>"
            echo ""
            echo "Actions:"
            echo "  create              - Create the build container (Fedora ${FEDORA_VERSION})"
            echo "  enter               - Enter the build container"
            echo "  status              - Show host and container Hyprland versions"
            echo "  update              - Update container packages to match host Hyprland"
            echo "  sync                - Copy headers, state, and plugins to host"
            echo "  rebuild             - Full automated rebuild (update → hyprpm update → sync → reload)"
            echo "  rebuild-interactive - Same as rebuild, but drops into shell for manual work"
            echo "  remove              - Remove the build container"
            echo ""
            echo "Workflow for rebuilding after Hyprland update (single command):"
            echo "  ujust setup-hyprland-build rebuild"
            echo ""
            echo "Workflow for new plugins:"
            echo "  1. ujust setup-hyprland-build create"
            echo "  2. ujust setup-hyprland-build enter"
            echo "  3. hyprpm update && hyprpm add <plugin-url>"
            echo "  4. exit"
            echo "  5. ujust setup-hyprland-build sync"
            echo "  6. hyprpm enable <plugin> && hyprpm reload"
            ;;
    esac
