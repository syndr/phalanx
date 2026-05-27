#!/bin/bash
# Install the newest non-draft Lan Mouse GitHub release, including prereleases.

if [[ "${TRACE:-0}" -ne 0 ]]; then
  set -ouex pipefail
else
  set -oue pipefail
fi

api_url="https://api.github.com/repos/feschber/lan-mouse/releases"
asset_name=""
release_json=""
tmpdir=""

case "$(uname -m)" in
  x86_64)
    asset_name="lan-mouse-linux-x86_64"
    ;;
  aarch64|arm64)
    asset_name="lan-mouse-linux-arm64"
    ;;
  *)
    echo "Unsupported architecture for Lan Mouse: $(uname -m)"
    exit 1
    ;;
esac

cleanup() {
  if [[ -n "$tmpdir" ]]; then
    rm -rf "$tmpdir"
  fi
}
trap cleanup EXIT

tmpdir="$(mktemp -d)"
release_json="${tmpdir}/releases.json"

echo "Resolving latest Lan Mouse release from GitHub"
curl --fail --location --retry 5 --retry-all-errors --silent --show-error \
  --header "Accept: application/vnd.github+json" \
  "$api_url" \
  --output "$release_json"

selected_release="$(jq -c 'map(select(.draft | not)) | sort_by(.published_at // .created_at) | last' "$release_json")"
selected_tag="$(jq -r '.tag_name // empty' <<< "$selected_release")"
asset_url="$(jq -r --arg name "$asset_name" '.assets[]? | select(.name == $name) | .browser_download_url // empty' <<< "$selected_release")"
asset_digest="$(jq -r --arg name "$asset_name" '.assets[]? | select(.name == $name) | .digest // empty' <<< "$selected_release")"

if [[ -z "$selected_tag" || -z "$asset_url" ]]; then
  echo "Unable to find ${asset_name} in the latest Lan Mouse release"
  jq -r '.[] | select(.draft | not) | "\(.tag_name) prerelease=\(.prerelease) published=\(.published_at)"' "$release_json"
  exit 1
fi

echo "Installing Lan Mouse ${selected_tag} from ${asset_url}"
curl --fail --location --retry 5 --retry-all-errors --silent --show-error \
  "$asset_url" \
  --output "${tmpdir}/lan-mouse"

if [[ "$asset_digest" == sha256:* ]]; then
  echo "${asset_digest#sha256:}  ${tmpdir}/lan-mouse" | sha256sum --check -
else
  echo "Lan Mouse release asset is missing a sha256 digest"
  exit 1
fi

install -Dm0755 "${tmpdir}/lan-mouse" /usr/bin/lan-mouse

raw_base="https://raw.githubusercontent.com/feschber/lan-mouse/${selected_tag}"

curl --fail --location --retry 5 --retry-all-errors --silent --show-error \
  "${raw_base}/de.feschber.LanMouse.desktop" \
  --output "${tmpdir}/de.feschber.LanMouse.desktop"
install -Dm0644 "${tmpdir}/de.feschber.LanMouse.desktop" /usr/share/applications/de.feschber.LanMouse.desktop

curl --fail --location --retry 5 --retry-all-errors --silent --show-error \
  "${raw_base}/lan-mouse-gtk/resources/de.feschber.LanMouse.svg" \
  --output "${tmpdir}/de.feschber.LanMouse.svg"
install -Dm0644 "${tmpdir}/de.feschber.LanMouse.svg" /usr/share/icons/hicolor/scalable/apps/de.feschber.LanMouse.svg

curl --fail --location --retry 5 --retry-all-errors --silent --show-error \
  "${raw_base}/firewall/lan-mouse.xml" \
  --output "${tmpdir}/lan-mouse.xml"
install -Dm0644 "${tmpdir}/lan-mouse.xml" /usr/lib/firewalld/services/lan-mouse.xml

curl --fail --location --retry 5 --retry-all-errors --silent --show-error \
  "${raw_base}/service/lan-mouse.service" \
  --output "${tmpdir}/lan-mouse.service"
install -Dm0644 "${tmpdir}/lan-mouse.service" /usr/lib/systemd/user/lan-mouse.service

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -q /usr/share/icons/hicolor || true
fi
