# syntax=docker/dockerfile:1
# =============================================================================
# Musher dev container base image.
#
# WHY THIS FILE EXISTS
#
# bun, uv and task are baked here rather than installed via
# ghcr.io/devcontainers-extra/features/{bun,uv,go-task}. All three route through
# nanolayer's gh-release installer, which enumerates release assets against
# api.github.com UNAUTHENTICATED:
#
#   nanolayer/installers/gh_release/resolvers/asset_resolver.py
#     urllib.request.urlopen(f"https://api.github.com/repos/{repo}/releases/tags/{tag}")
#
# There is no Authorization header and no GITHUB_TOKEN read anywhere in that
# module. Codespaces build hosts and GitHub-hosted Actions runners share egress
# IP pools, so the 60 req/hr anonymous limit is routinely exhausted and the
# build dies with:
#
#   urllib.error.HTTPError: HTTP Error 403: rate limit exceeded
#   ERROR: Failed to install Bun. No asset patterns matched.
#
# That message is misleading -- the asset pattern was fine, the API call 403'd.
# PINNING THE VERSION DOES NOT HELP: the pin only supplies the tag, and
# _get_release_assets() still calls the API to LIST the release's assets.
#
# One failed Feature fails the whole image build, and Codespaces then falls back
# to a bare recovery container with none of the toolchain -- so the developer
# sees "task: command not found" rather than the real error.
#
# Every installer below fetches its artifact directly (bun -> bun.sh, uv ->
# astral.sh, task -> github.com/.../releases/download, mise -> mise.run). None
# touches api.github.com, so none can be starved by a noisy neighbour.
#
# Features that stay in devcontainer.json were checked individually and are
# clean: devcontainers-extra/deno curls releases/download/... directly,
# lukewiwa/shellcheck does the same, and robbert229/postgresql-client is apt.
#
# This boundary is enforced, not just documented -- see `repo toolchain check`
# (.repo/governance/policies/toolchain/).
#
# WHAT DOES *NOT* BELONG HERE
#
# The rule is: this file bakes version-pinned tools; scripts/post-create.sh owns
# whatever is inherently runtime or self-updating. In particular `mise install`
# cannot run here -- four of the six entries in mise.toml use the npm: and pipx:
# backends, and Node and Python arrive from Features, which layer AFTER this
# stage. Only the mise binary is baked.
#
# Pinned to the 24.04 LTS tag: the floating `:ubuntu` tag rolls forward to
# interim releases (e.g. 25.10) that docker-in-docker does not support.
# =============================================================================
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# `curl | bash` reports the exit status of bash, so a curl that dies mid-stream
# yields an empty script, a successful shell, and an image missing a tool. That
# silent-success shape is the failure class this file exists to remove, so make
# the pipe honest.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Image-baked tool pins. These ARGs are the single source of truth for the four
# tools below -- there is deliberately no versions file, because nothing outside
# this image consumes them. `repo toolchain check` asserts each is a concrete
# version (TC-02) and that TASK_VERSION matches CI's setup-task pin (TC-03).
ARG BUN_VERSION=1.3.14
ARG UV_VERSION=0.11.28
ARG TASK_VERSION=3.52.0
ARG MISE_VERSION=v2026.8.6

RUN set -eux; \
    # bun's installer hard-requires unzip, which the base image ships. Assert
    # rather than apt-install a fallback: an unpinned `apt-get install` would be
    # the only unpinned thing in this image, and a base that stopped shipping
    # unzip is a decision someone should have to make explicitly.
    command -v unzip >/dev/null 2>&1 || { echo "unzip missing from the base image; bun's installer requires it" >&2; exit 1; }; \
    \
    # --- bun -> /usr/local/bin/{bun,bunx}  (BUN_INSTALL=/usr/local => $BUN_INSTALL/bin)
    # Arch and the avx2 baseline variant are chosen by the installer; do not
    # hardcode either (Codespaces is x86_64, some dev machines are aarch64).
    # HOME is redirected to a scratch dir because the installer unconditionally
    # appends PATH exports to ~/.bashrc and ~/.zshrc when they are writable.
    mkdir -p /tmp/bun-home; \
    HOME=/tmp/bun-home BUN_INSTALL=/usr/local bash -c \
      "curl --retry 5 --retry-all-errors --retry-delay 3 -fsSL https://bun.sh/install \
       | bash -s bun-v${BUN_VERSION}"; \
    rm -rf /tmp/bun-home; \
    # `bunx` needs no wrapper: the installer creates it as a symlink to `bun`.
    # Do NOT `printf > /usr/local/bin/bunx` to "recreate" it -- that follows the
    # symlink and overwrites the ~90 MB bun binary with the wrapper text, after
    # which every `bun` call recurses into itself and hangs.
    \
    # --- uv -> /usr/local/bin/{uv,uvx}
    curl --retry 5 --retry-all-errors --retry-delay 3 -LsSf \
      "https://astral.sh/uv/${UV_VERSION}/install.sh" \
      | env UV_INSTALL_DIR=/usr/local/bin INSTALLER_NO_MODIFY_PATH=1 sh; \
    \
    # --- task -> /usr/local/bin/task
    # godownloader script: downloads the release tarball and its checksum file
    # from github.com/go-task/task/releases/download and sha256-verifies before
    # installing. `-b` sets bindir; the trailing arg is the tag.
    curl --retry 5 --retry-all-errors --retry-delay 3 -fsSL https://taskfile.dev/install.sh \
      | sh -s -- -b /usr/local/bin "v${TASK_VERSION}"; \
    \
    # --- mise -> /usr/local/bin/mise
    # Installed system-wide and version-pinned. Previously this was an unpinned
    # `curl https://mise.run | sh` in post-create -- the only unpinned tool in a
    # repo that pins everything else. The per-user shim dir that remoteEnv PATH
    # expects (~/.local/share/mise/shims) is still created at runtime by
    # `mise reshim` in base-setup.sh.
    MISE_VERSION="${MISE_VERSION}" MISE_INSTALL_PATH=/usr/local/bin/mise \
      bash -c 'curl --retry 5 --retry-all-errors --retry-delay 3 -fsSL https://mise.run | sh'; \
    \
    # Fail THIS layer, loudly, rather than letting post-create discover it.
    #
    # Presence-only on purpose. The pinned download URLs already guarantee the
    # versions -- a wrong version 404s -- and asserting them by executing the
    # binaries in the same layer that installed them is a known hazard under
    # BuildKit. The runtime version assertion lives in
    # scripts/verify-toolchain.sh, which CI runs against the built container.
    test -x /usr/local/bin/bun; \
    test -x /usr/local/bin/bunx; \
    test -x /usr/local/bin/uv; \
    test -x /usr/local/bin/uvx; \
    test -x /usr/local/bin/task; \
    test -x /usr/local/bin/mise

# No `USER vscode` here on purpose: Features install after this stage and
# `updateRemoteUserUID` expects root at build time. devcontainer.json's
# `remoteUser` owns runtime identity.
