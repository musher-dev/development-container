#!/usr/bin/env bash
# common.sh — Shared utility functions for dev container setup scripts.
set -euo pipefail

# --- Logging ---

log() {
  echo "[$(date '+%H:%M:%S')] $*"
}

# --- Command helpers ---

has_cmd() {
  command -v "$1" &>/dev/null
}

retry() {
  local attempts="${1:?usage: retry <attempts> <delay> <command...>}"
  local delay="${2:?}"
  shift 2
  local attempt=1
  while true; do
    if "$@"; then
      return 0
    fi
    if ((attempt >= attempts)); then
      log "FAIL: '$*' failed after ${attempts} attempts"
      return 1
    fi
    log "Attempt ${attempt}/${attempts} failed, retrying in ${delay}s..."
    sleep "$delay"
    ((attempt++))
  done
}

# --- Directory helpers ---

ensure_writable_dir() {
  local dir="${1:?usage: ensure_writable_dir <path>}"
  local owner="${2:-vscode}"
  if [[ ! -d "$dir" ]]; then
    sudo mkdir -p "$dir"
  fi
  sudo chown -R "${owner}:${owner}" "$dir"
}

setup_config_dirs() {
  # Takes arguments in "label:path" format.
  # Example: setup_config_dirs "gh config:/home/vscode/.config/gh" "claude:/home/vscode/.claude"
  local owner="${REMOTE_USER:-vscode}"
  for entry in "$@"; do
    local label="${entry%%:*}"
    local dir="${entry#*:}"
    log "Ensuring config dir: ${label} (${dir})"
    ensure_writable_dir "$dir" "$owner"
  done
}

# --- NVM helpers ---

fix_nvm_permissions() {
  local nvm_dir="${NVM_DIR:-/usr/local/share/nvm}"
  if [[ -d "$nvm_dir" ]]; then
    log "Fixing NVM permissions in ${nvm_dir}..."
    sudo chown -R "$(id -un):$(id -gn)" "$nvm_dir"
  fi
}

# --- NPM install helper ---

install_npm_cli() {
  local package="${1:?usage: install_npm_cli <package> [attempts]}"
  local attempts="${2:-3}"
  log "Installing npm CLI: ${package}..."
  retry "$attempts" 5 npm install -g "$package"
}

# --- Verification ---

verify_tools() {
  # Takes a list of command names to verify.
  log "Verifying installed tools..."
  local all_ok=true
  for cmd in "$@"; do
    if has_cmd "$cmd"; then
      log "  ✓ ${cmd}: $("$cmd" --version 2>/dev/null || echo 'installed')"
    else
      log "  ✗ ${cmd}: MISSING"
      all_ok=false
    fi
  done
  $all_ok
}
