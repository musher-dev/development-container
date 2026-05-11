#!/usr/bin/env bash
# post-create.sh — DevContainer post-create command hook.
#
# Runs once after the container is created. Sets up environment files,
# invokes the base setup orchestrator, and configures shell customization.
#
# Usage: Called automatically by devcontainer.json postCreateCommand.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/base-setup.sh
source "${SCRIPT_DIR}/lib/base-setup.sh"

# Logs the failing command and line number on ERR.
#
# Arguments:
#   $1 — line number
#   $2 — failed command string
# Outputs:
#   Writes error details to stderr via log()
on_error() {
  local line="${1}"
  local cmd="${2}"
  log "ERROR: command '${cmd}' failed at line ${line}"
}
trap 'on_error ${LINENO} "${BASH_COMMAND}"' ERR

# Installs lefthook git hooks for this repo. Best-effort: silently
# skips if lefthook isn't on PATH yet or no lefthook.yml exists.
#
# Outputs:
#   Writes progress to stderr via log()
install_lefthook_hooks() {
  command -v lefthook >/dev/null 2>&1 || return 0
  [[ -f "${SCRIPT_DIR}/../../lefthook.yml" ]] || return 0
  log "Installing lefthook git hooks..."
  (cd "${SCRIPT_DIR}/../.." && lefthook install >/dev/null 2>&1) || true
}

# Appends shell customization sourcing block to .zshrc.
#
# The heredoc below intentionally expands ${shell_dir} at write-time so the
# absolute path is baked into .zshrc, avoiding runtime resolution.
#
# Globals:
#   REMOTE_USER — read, falls back to "vscode"
# Outputs:
#   Writes progress to stderr via log()
setup_shell_customization() {
  local shell_dir
  shell_dir="$(cd "${SCRIPT_DIR}/../config/shell" 2>/dev/null && pwd)" || return 0
  local zshrc="/home/${REMOTE_USER:-vscode}/.zshrc"
  local marker="# --- musher shell customization ---"

  if ! grep -qF "$marker" "$zshrc" 2>/dev/null; then
    log "Configuring shell customization sourcing..."
    # NOTE: ${shell_dir} is intentionally expanded at write-time (unquoted heredoc).
    cat >> "$zshrc" <<EOF

$marker
for f in ${shell_dir}/*.shared.sh(N); do
  [ -f "\$f" ] && source "\$f"
done
for f in ${shell_dir}/*.local.sh(N); do
  [ -f "\$f" ] && source "\$f"
done
EOF
  fi
}

# Entry point: runs the full post-create setup sequence.
#
# Arguments:
#   $@ — passed through (unused, reserved for future use)
# Outputs:
#   Writes progress to stderr via log()
main() {
  log "Starting post-create setup..."
  base_setup
  install_lefthook_hooks
  setup_shell_customization
  # --- Add repo-specific setup below ---
  log "Post-create setup completed"
}

main "$@"
