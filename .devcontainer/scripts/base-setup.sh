#!/usr/bin/env bash
# base-setup.sh — Reusable setup orchestrator for musher dev containers.
# Source this file and call base_setup, or call individual functions to customize.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

# --- Config directories ---

base_setup_config_dirs() {
  setup_config_dirs \
    "gh config:/home/vscode/.config/gh" \
    "claude:/home/vscode/.claude"
}

# --- NVM ---

base_fix_nvm_permissions() {
  fix_nvm_permissions
}

# --- Task runner ---

base_install_task() {
  if has_cmd task; then
    log "Task already installed, skipping"
    return 0
  fi
  log "Installing Task runner..."
  retry 3 5 bash -c 'curl -fsSL https://taskfile.dev/install.sh | sh -s -- -d -b /usr/local/bin'
}

# --- Claude CLI ---

base_install_claude() {
  if has_cmd claude; then
    log "Claude CLI already installed, skipping"
    return 0
  fi
  log "Installing Claude CLI..."
  retry 3 5 bash -c 'curl -fsSL https://claude.ai/install.sh | bash'
}

# --- Codex CLI ---

base_install_codex() {
  if has_cmd codex; then
    log "Codex CLI already installed, skipping"
    return 0
  fi
  install_npm_cli "@openai/codex"
}

# --- Verify ---

base_verify_tools() {
  verify_tools gh claude task codex
}

# --- Orchestrator ---

base_setup() {
  log "Running base setup..."
  base_setup_config_dirs
  base_fix_nvm_permissions
  base_install_task
  base_install_claude
  base_install_codex
  base_verify_tools
  log "Base setup complete"
}
