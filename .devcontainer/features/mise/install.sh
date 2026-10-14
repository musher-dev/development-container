#!/usr/bin/env bash
# install.sh — the local mise Feature (.devcontainer/features/mise/).
#
# Runs as root at build time. mise.run downloads the release asset straight
# from github.com/jdx/mise/releases/download/, so a pinned version makes no
# api.github.com call: the rate limit that ruled out devcontainers-extra's mise
# Feature (it resolves every version through the API) never applies.
#
# Presence-only check here; verify-toolchain.sh asserts the version, because
# running a binary in the layer that installed it is a known BuildKit hazard.
set -euo pipefail

VERSION="${VERSION:?set the version option}"
readonly INSTALL_PATH=/usr/local/bin/mise

curl --retry 5 --retry-all-errors --retry-delay 3 -fsSL https://mise.run \
  | MISE_VERSION="v${VERSION#v}" MISE_INSTALL_PATH="${INSTALL_PATH}" sh
test -x "${INSTALL_PATH}"
