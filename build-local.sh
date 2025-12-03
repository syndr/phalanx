#!/bin/bash

# Usage: ./build-local.sh [permutation] [image_suffix]
# Example: ./build-local.sh hyprland nvidia

# Check for -h/--help
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "Usage: $0 [permutation] [image_suffix] [-v]"
  echo "  permutation   : Variant of the image to build (default: base)"
  echo "  image_suffix  : Suffix for upstream image base (e.g., nvidia)"
  echo "  -v            : Enable verbose (trace) mode"
  echo "Environment variables:"
  echo "  IMAGE_NAME_OVERRIDE : Override the generated image name"
  echo "  IMAGE_SUFFIX        : Alternative way to specify image_suffix argument"
  exit 0
fi

# Check for -v (trace mode)
TRACE=0
NEW_ARGS=()
for arg in "$@"; do
  if [[ "$arg" == "-v" ]]; then
    TRACE=1
  else
    NEW_ARGS+=("$arg")
  fi
done
set -- "${NEW_ARGS[@]}"

if [[ $TRACE -eq 1 ]]; then
  set -ouex pipefail
else
  set -oue pipefail
fi

PERMUTATION="${1:-base}"
IMAGE_SUFFIX="${2:-${IMAGE_SUFFIX:-}}"
CONTAINERFILE="Containerfile"
BUILD_SCRIPT="build/${PERMUTATION}/build.sh"

if [ ! -f "$BUILD_SCRIPT" ]; then
  echo "Build script not found for variant: $PERMUTATION"
  echo "Expected: $BUILD_SCRIPT"
  exit 1
fi

# Generate image name (similar to GitHub Actions logic)
REPO_NAME="$(basename $(pwd))"

if [ -n "$IMAGE_SUFFIX" ]; then
  IMAGE_SUFFIX_TAG="-$IMAGE_SUFFIX"
else
  IMAGE_SUFFIX_TAG=""
fi

IMAGE_NAME="${REPO_NAME}-${PERMUTATION}${IMAGE_SUFFIX_TAG}:local"

# Optionally allow override via env var (fix unbound variable error)
if [ -n "${IMAGE_NAME_OVERRIDE:-}" ]; then
  IMAGE_NAME="$IMAGE_NAME_OVERRIDE"
fi

echo "Building image: $IMAGE_NAME using $CONTAINERFILE"

buildah bud -f "$CONTAINERFILE" -t "$IMAGE_NAME" \
  --build-arg VARIANT="$PERMUTATION" \
  --build-arg SOURCE_SUFFIX="$IMAGE_SUFFIX_TAG" .

echo "Image built locally as $IMAGE_NAME. Not pushing to any registry."
