#!/usr/bin/env bash
# Builds the custom "opencloud-unzip-server" backend image from the
# ccycle/opencloud fork's feat/unzip-service branch, for the mac-mini-m4-pro
# profile's self-hosted deployment (see modules/opencloud/design.md and
# modules/mac-mini-m4-pro/darwin.nix's `services.opencloud.image` override).
#
# Not a Nix derivation: no service module in this repo builds Docker images
# via Nix (dockerTools/buildGoModule), every one references a pre-built image
# tag instead. This script produces that tag; Nix only references it by name.
#
# services/web and services/idp ship their frontend assets as empty
# placeholders in git (go:embed requires *something* on disk at build time) -
# the Makefile targets below populate them before the Go build can embed them.
set -euo pipefail

REPO_DIR="${1:-$HOME/repositories/github.com/ccycle/opencloud}"
IMAGE_TAG="${IMAGE_TAG:-opencloud-unzip-server:latest}"
TARGETARCH="${TARGETARCH:-arm64}"

if [ ! -d "$REPO_DIR/.git" ]; then
  echo "error: $REPO_DIR is not a git checkout (pass the opencloud fork's path as \$1)" >&2
  exit 1
fi

cd "$REPO_DIR"

branch=$(git branch --show-current)
if [ "$branch" != "feat/unzip-service" ]; then
  echo "warning: building from branch '$branch', not 'feat/unzip-service'" >&2
fi

echo "==> pulling opencloud-eu/web's pinned release frontend assets"
make -C services/web download-assets

echo "==> building the IDP frontend"
make -C services/idp assets

echo "==> building the image (--no-cache: the Dockerfile's RUN --mount=type=bind,rw"
echo "    Go build step does not reliably invalidate its cache on source edits)"
docker build --no-cache \
  -f opencloud/docker/Dockerfile.multiarch \
  --build-arg TARGETARCH="$TARGETARCH" \
  -t "$IMAGE_TAG" \
  .

echo "==> built $IMAGE_TAG"
