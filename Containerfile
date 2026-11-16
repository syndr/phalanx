## 1. BUILD ARGS
# These allow changing the produced image by passing different build args to adjust
# the source from which your image is built.
# Build args can be provided on the commandline when building locally with:
#   podman build -f Containerfile --build-arg FEDORA_VERSION=40 -t local-image

# SOURCE_IMAGE arg can be anything from ublue upstream which matches your desired version:
# See list here: https://github.com/orgs/ublue-os/packages?repo_name=main
# - "silverblue"
# - "kinoite"
# - "sericea"
# - "onyx"
# - "lazurite"
# - "vauxite"
# - "base"
#
#  "aurora", "bazzite", "bluefin" or "ucore" may also be used but have different suffixes.
ARG SOURCE_IMAGE="bazzite"

## SOURCE_SUFFIX arg should include a hyphen and the appropriate suffix name
# These examples all work for silverblue/kinoite/sericea/onyx/lazurite/vauxite/base
# - "-main"
# - "-nvidia"
# - "-asus"
# - "-asus-nvidia"
# - "-surface"
# - "-surface-nvidia"
#
# aurora, bazzite and bluefin each have unique suffixes. Please check the specific image.
# ucore has the following possible suffixes
# - stable
# - stable-nvidia
# - stable-zfs
# - stable-nvidia-zfs
# - (and the above with testing rather than stable)
ARG SOURCE_SUFFIX=""

## SOURCE_TAG arg must be a version built for the specific image: eg, 39, 40, gts, latest
ARG SOURCE_TAG="stable"

## VARIANT arg specifies which build variant to use: base, awesome, workstation, hyprland
ARG VARIANT="base"

# This must be the folder containing the build script and any other files needed for the build
ARG WORKING_DIR="/tmp/build/${VARIANT}"

# LAN_MOUSE_TAG / LAN_MOUSE_URL / LAN_MOUSE_DIGEST: pre-resolved Lan Mouse
# release (tag, asset download URL, sha256 digest). The CI workflow resolves
# them on the host with a GITHUB token - api.github.com rate-limits
# unauthenticated calls per shared runner IP. Empty by default: the build
# script falls back to resolving via the API (local builds).
ARG LAN_MOUSE_TAG=""
ARG LAN_MOUSE_URL=""
ARG LAN_MOUSE_DIGEST=""

### 2. SOURCE IMAGE
## this is a standard Containerfile FROM using the build ARGs above to select the right upstream image
FROM ghcr.io/ublue-os/${SOURCE_IMAGE}${SOURCE_SUFFIX}:${SOURCE_TAG}

### 3. MODIFICATIONS

COPY build /tmp/build

# Declare ARG again after FROM to make it available in RUN
ARG VARIANT=base

# Lan Mouse release values pre-resolved by the CI workflow on the host, with a
# GITHUB token: api.github.com rate-limits unauthenticated calls per IP (60/h)
# and runner egress IPs are shared, so resolving inside the image build 403s
# under load. Only resolved values are passed - never a token (build args land
# in the pushed image config). When empty, install-lan-mouse.sh falls back to
# resolving via the API itself (local builds).
ARG LAN_MOUSE_TAG=""
ARG LAN_MOUSE_URL=""
ARG LAN_MOUSE_DIGEST=""

RUN mkdir -p /var/lib/alternatives && \
    cd /tmp/build/${VARIANT} && \
    ./build.sh
# The bazzite base (fc45+) is bootc-native: there is no ostree repo in the
# rootfs and `ostree container commit` no longer applies (it fails with
# "Not in an ostree-based container environment"). Package changes are plain
# OCI layers that bootc consumes as-is, and buildah carries the base's bootc
# metadata into the derived image, so no explicit commit step is needed.
# `bootc container lint` is the supported build-time validation. dnf5 cache
# and logs are removed first so /var stays clean (lint warns on /var content).
RUN dnf5 clean all && \
    rm -rf /var/cache/libdnf5 /var/lib/dnf /var/log/dnf5.log && \
    bootc container lint

## NOTES:
# - /var/lib/alternatives is required to prevent failure with some RPM installs
# - Package changes go through dnf5 (bootc-native base; rpm-ostree no longer
#   works in container builds on fc45+ bases)
# - `bootc container lint` is the final build step (replaces the legacy
#   `ostree container commit`); see docs/adr/build-on-bootc-native-bases.md
