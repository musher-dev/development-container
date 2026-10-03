# syntax=docker/dockerfile:1
# Musher dev container base image.
#
# This bakes only mise and the lifecycle scripts. Every other CLI is a pin in
# the consuming repo's .config/mise/config.toml, which post-create installs
# with `mise install --locked`: the lockfile's recorded URLs avoid the
# unauthenticated api.github.com calls that once made Features rate-limit.
# The Features and the rest of the configuration ride in this image's
# devcontainer.metadata label (.devcontainer/image/devcontainer.json).
#
# Pinned to the LTS tag: floating `:ubuntu` rolls to interim releases that
# docker-in-docker does not support.
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# OUT-13: GHCR links the package to the repository that publishes it.
LABEL org.opencontainers.image.source="https://github.com/musher-dev/development-container"

# Without pipefail a truncated `curl | sh` reports sh's exit status, giving a
# successful build and an image with no tool in it.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Keep in lockstep with min_version in .config/mise/config.toml (TOOL-04).
ARG MISE_VERSION=v2026.8.6

# System-wide; base-setup.sh still runs `mise reshim` to build the per-user
# shim dir that remoteEnv's PATH expects. Presence-only here: the version check
# lives in verify-toolchain.sh, because running a binary in the layer that
# installed it is a known BuildKit hazard.
RUN curl --retry 5 --retry-all-errors --retry-delay 3 -fsSL https://mise.run \
      | MISE_VERSION="${MISE_VERSION}" MISE_INSTALL_PATH=/usr/local/bin/mise sh \
    && test -x /usr/local/bin/mise

# The lifecycle scripts the metadata's postCreateCommand / postStartCommand
# run. A consuming repo carries no copy of them.
COPY scripts/ /usr/local/share/musher-devcontainer/

# No USER: Features install after this stage and updateRemoteUserUID expects
# root at build time. devcontainer.json's remoteUser owns runtime identity.
