#!/usr/bin/env bash
# base-setup.sh — Reusable setup orchestrator for musher dev containers.
#
# This file is intended to be sourced, not executed directly.
# Source it and call base_setup, or call individual functions to customize.
#
# Usage:
#   source "path/to/base-setup.sh"
#   base_setup
set -euo pipefail

# Guard against direct execution — this file must be sourced.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Error: source this file, don't execute it" >&2
  exit 1
fi

_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly _LIB_DIR
readonly _HOME="/home/${REMOTE_USER:-vscode}"

# shellcheck source=common.sh
source "${_LIB_DIR}/common.sh"

_WORKSPACE="$(workspace_root)"
readonly _WORKSPACE

# --- Config directories ---

# Creates standard config directories for dev tools.
#
# Globals:
#   _HOME — read, user home directory
# Outputs:
#   Writes progress to stderr via log()
base_setup_config_dirs() {
  setup_config_dirs \
    "gh config:${_HOME}/.config/gh" \
    "claude:${_HOME}/.claude" \
    "codex:${_HOME}/.codex"
}

# --- Cache directories ---

# Creates cache directories for all dev tools so caches land
# under a single tree instead of scattering across the filesystem.
#
# Globals:
#   _HOME — read, user home directory
# Outputs:
#   Writes progress to stderr via log()
base_setup_cache_dirs() {
  setup_config_dirs \
    "xdg cache:${_HOME}/.cache" \
    "uv cache:${_HOME}/.cache/uv" \
    "ruff cache:${_HOME}/.cache/ruff" \
    "pip cache:${_HOME}/.cache/pip" \
    "mypy cache:${_HOME}/.cache/mypy" \
    "npm cache:${_HOME}/.cache/npm" \
    "deno cache:${_HOME}/.cache/deno" \
    "go mod cache:${_HOME}/.cache/go/mod" \
    "go build cache:${_HOME}/.cache/go/build" \
    "bun cache:${_HOME}/.cache/bun"
}

# --- NVM ---

# The Node feature installs Node via nvm; fix nvm's ownership so global npm
# installs work. Delegates to fix_nvm_permissions from common.sh.
base_fix_nvm_permissions() {
  fix_nvm_permissions
}

# Enables corepack, so a package.json `packageManager` field (pnpm@…,
# yarn@…) resolves to exactly that version with no global install. Needs the
# nvm ownership fix above: the shims land beside node.
#
# Outputs:
#   Writes progress to stderr via log()
base_enable_corepack() {
  if ! has_cmd corepack; then
    log "corepack not on PATH, skipping"
    return 0
  fi
  log "Enabling corepack (pnpm, yarn)..."
  corepack enable || log "WARNING: corepack enable failed"
}

# --- mise (pins the CLIs that have no devcontainer Feature) ---

# Fallback only: the mise Feature (.devcontainer/features/mise/) installs mise
# at /usr/local/bin/mise, which `command -v` finds first. This path covers the
# base_install_mise fallback, which installs per-user.
readonly _MISE_BIN="${_HOME}/.local/bin/mise"
readonly _MISE_SHIMS="${_HOME}/.local/share/mise/shims"

# Puts the mise shims and ~/.local/bin on PATH for the rest of this script, so
# mise-managed CLIs and Claude are visible to base_verify_tools. The mise
# Feature already sets the shims in containerEnv; this covers a repo without
# it, and ~/.local/bin, which only remoteEnv adds (lifecycle hooks don't always
# inherit remoteEnv).
#
# Globals:
#   PATH — modified (export)
base_setup_path() {
  export PATH="${_MISE_SHIMS}:${_HOME}/.local/bin:${PATH}"
}

# Installs mise if it is not already present.
#
# The mise Feature installs it at build time, so this normally short-circuits.
# The fallback covers a repo that drops the Feature, and installs the same
# version: the configuration's min_version. mise.run downloads a release asset
# from github.com, not through api.github.com.
#
# Globals:
#   _WORKSPACE — read, the repo root
# Outputs:
#   Writes progress to stderr via log()
# Returns:
#   0 on success, non-zero on failure
base_install_mise() {
  if has_cmd mise; then
    log "mise already installed, skipping"
    return 0
  fi
  local version
  version="$(mise_min_version "${_WORKSPACE}")" || {
    log "No min_version in .config/mise/config.toml, skipping mise"
    return 0
  }
  log "mise Feature absent; installing mise ${version} from https://mise.run..."
  retry 3 5 env MISE_VERSION="v${version}" bash -c 'curl -fsSL https://mise.run | sh'
}

# Installs the CLIs the workspace pins in .config/mise/config.toml, then
# regenerates shims. mise finds that file itself from the workspace root.
#
# --locked installs from the URLs and checksums mise.lock records, so it makes
# no GitHub API calls; a repo without a lockfile gets a plain install.
#
# Globals:
#   _WORKSPACE — read, the repo root
# Outputs:
#   Writes progress to stderr via log()
# Returns:
#   0 on success, non-zero on failure
base_install_tools() {
  local mise
  mise="$(command -v mise || echo "${_MISE_BIN}")"
  local config="${_WORKSPACE}/.config/mise/config.toml"
  if [[ ! -f "${config}" ]]; then
    log "No ${config}, skipping pinned CLIs"
    return 0
  fi
  local locked=()
  [[ -f "${_WORKSPACE}/.config/mise/mise.lock" ]] && locked=(--locked)
  log "Installing pinned CLIs from ${config}..."
  "${mise}" trust "${config}" >/dev/null 2>&1 || true
  (cd "${_WORKSPACE}" && retry 3 5 "${mise}" install "${locked[@]}")
  "${mise}" reshim >/dev/null 2>&1 || true
}

# --- Claude Code ---

# Installs Claude Code via the native installer if not already present.
#
# Outputs:
#   Writes progress to stderr via log()
# Returns:
#   0 on success, non-zero on failure
base_install_claude() {
  if has_cmd claude; then
    log "Claude Code already installed, skipping"
    return 0
  fi
  log "Installing Claude Code (native installer)..."
  retry 3 5 bash -c 'curl -fsSL https://claude.ai/install.sh | bash'
}

# --- Repo governance CLI ---

# The governance CLI's project in this workspace, if it carries one.
readonly _REPO_PROJECT="${_WORKSPACE}/.repo"

# Installs the `repo` CLI: the scaffold's env tools (`repo env sync` writes
# .devcontainer/.env) and its structure policies.
#
# From the workspace's .repo/, so an edited policy takes effect. A repository
# that drops .repo/ gets no `repo`; post-create then falls back to
# `conventions env-file` for a first .env.
#
# Sequenced after base_install_tools because it needs uv on PATH, and before
# base_verify_tools because that call asserts `repo` resolves.
#
# Globals:
#   _REPO_PROJECT — read
# Outputs:
#   Writes progress to stderr via log()
# Returns:
#   0 on success, non-zero on failure
base_install_repo_cli() {
  if ! has_cmd uv; then
    log "uv not on PATH, skipping the repo CLI"
    return 0
  fi
  if [[ ! -f "${_REPO_PROJECT}/pyproject.toml" ]]; then
    log "No .repo/, skipping the repo CLI"
    return 0
  fi
  log "Installing the repo CLI from .repo/..."
  retry 3 5 uv tool install --force --reinstall "${_REPO_PROJECT}"
}

# --- Verify ---

# Verifies the CLIs this repo opted into are on PATH. Runtimes are validated
# by the container build itself.
#
# Only gh and claude are unconditional. `repo` is checked when
# the workspace carries .repo/, lefthook when the repo has a
# lefthook config, and every tool the mise config pins (task, uv, codex,
# linters, ...) by `mise ls --missing`, so a consumer that drops a pin is never
# failed for it.
#
# Outputs:
#   Writes tool status to stderr via log()
# Returns:
#   0 if all tools found, 1 if any are missing
base_verify_tools() {
  local tools=(gh claude)
  [[ -f "${_REPO_PROJECT}/pyproject.toml" ]] && tools+=(repo)
  lefthook_config "${_WORKSPACE}" >/dev/null && tools+=(lefthook)
  local ok=0
  verify_tools "${tools[@]}" || ok=1

  local missing
  missing="$(cd "${_WORKSPACE}" && mise ls --missing --no-header 2>/dev/null || true)"
  if [[ -n "${missing}" ]]; then
    log "  ✗ mise pins not installed:"
    log "${missing}"
    ok=1
  fi
  return "${ok}"
}

# --- Orchestrator ---

# Runs the complete base setup sequence.
#
# Outputs:
#   Writes progress to stderr via log()
base_setup() {
  log "Running base setup..."
  base_setup_config_dirs
  base_setup_cache_dirs
  base_fix_nvm_permissions
  base_enable_corepack
  base_setup_path
  base_install_mise
  base_install_tools
  base_install_claude
  base_install_repo_cli
  base_verify_tools
  log "Base setup complete"
}
