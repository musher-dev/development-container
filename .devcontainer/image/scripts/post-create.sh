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

WORKSPACE="$(workspace_root)"
readonly WORKSPACE

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

# Writes .devcontainer/.env from the schema, or brings it up to date, and wires
# the shell profiles to load it.
#
# Nothing commits a .env template (ENVS-26), so the file is generated here,
# inside the container: `repo env sync` writes it on first create and later
# only adds bindings the schema has gained and mints local secrets -- it never
# overwrites a live value, so it is safe on every create. Without the repo CLI,
# `conventions env-file` writes a first copy. The profile line is what makes an
# edited .env reach new terminals without a rebuild; see lib/env-load.sh.
#
# Globals:
#   SCRIPT_DIR, WORKSPACE — read
# Outputs:
#   Writes progress to stderr via log()
setup_env_file() {
  local loader="${SCRIPT_DIR}/lib/env-load.sh"
  local schema="${WORKSPACE}/.devcontainer/env.schema.yaml"
  local env_file="${WORKSPACE}/.devcontainer/.env"
  local marker="# musher devcontainer env (post-create)"

  if [[ -f "${schema}" ]]; then
    if has_cmd repo; then
      log "Syncing .devcontainer/.env with the schema..."
      (cd "${WORKSPACE}" && repo env sync) || log "WARNING: repo env sync failed"
    elif has_cmd conventions && [[ ! -f "${env_file}" ]]; then
      log "Writing .devcontainer/.env from the schema..."
      (cd "${WORKSPACE}" && conventions env-file "${schema}") || log "WARNING: conventions env-file failed"
    fi
  fi

  local rc
  for rc in "${HOME}/.zshrc" "${HOME}/.bashrc"; do
    [[ -f "${rc}" ]] || continue
    grep -qF "${marker}" "${rc}" && continue
    {
      echo ""
      echo "${marker}"
      echo "[ -f \"${loader}\" ] && . \"${loader}\" && env_load \"${env_file}\""
    } >> "${rc}"
  done
}

# Installs lefthook git hooks for this repo. Best-effort: silently
# skips if lefthook isn't on PATH yet or the repo has no lefthook config.
#
# The config check matters: `lefthook install` with no config writes a root
# lefthook.yml, which would shadow .config/lefthook.yml.
#
# Outputs:
#   Writes progress to stderr via log()
install_lefthook_hooks() {
  command -v lefthook >/dev/null 2>&1 || return 0
  lefthook_config "${WORKSPACE}" >/dev/null || return 0
  log "Installing lefthook git hooks..."
  (cd "${WORKSPACE}" && lefthook install >/dev/null 2>&1) || true
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
  setup_env_file
  install_lefthook_hooks
  # --- Add repo-specific setup below ---
  log "Post-create setup completed"
}

main "$@"
