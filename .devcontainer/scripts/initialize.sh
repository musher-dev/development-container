#!/usr/bin/env bash
# initialize.sh — Host-side bootstrap for the dev container.
#
# Runs on the host via `initializeCommand`, before `docker run` — it has to,
# because `runArgs --env-file` is evaluated at `docker run` time, so .env must
# already exist. post-create.sh would be too late.
#
# The CRLF guard here is not redundant with .gitattributes. That normalizes
# every file Git checks out, which is why the old postCreate fix-crlf step
# could go; it cannot reach .env, which is gitignored, generated locally and
# hand-edited, so a Windows editor can reintroduce CR at any time. Docker
# rejects an --env-file containing CRLF.
#
# Idempotent: safe to run on every container start.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly DEVCONTAINER_DIR="${SCRIPT_DIR}/.."
readonly ENV_FILE="${DEVCONTAINER_DIR}/.env"
readonly ENV_EXAMPLE="${DEVCONTAINER_DIR}/.env.example"

log() {
  echo "[initialize] $*" >&2
}

ensure_env_file() {
  if [[ -f "${ENV_FILE}" ]]; then
    return 0
  fi
  if [[ -f "${ENV_EXAMPLE}" ]]; then
    log "Creating .devcontainer/.env from .env.example"
    cp "${ENV_EXAMPLE}" "${ENV_FILE}"
  else
    log "No .env.example found; creating empty .devcontainer/.env"
    : > "${ENV_FILE}"
  fi
}

# Not redundant with .gitattributes: .env is gitignored, so Git never
# normalizes it. See the header note.
strip_crlf() {
  [[ -f "${ENV_FILE}" ]] || return 0
  if grep -q $'\r' "${ENV_FILE}" 2>/dev/null; then
    log "Stripping CRLF from .devcontainer/.env"
    sed -i 's/\r$//' "${ENV_FILE}"
  fi
}

main() {
  ensure_env_file
  strip_crlf
}

main "$@"
