#!/usr/bin/env bash
# startup.sh — Starts compose services and waits for health checks.
#
# Executed on every container start to bring up supporting services
# (databases, caches, observability) defined in compose.yaml.
#
# Usage: Called automatically by devcontainer.json postStartCommand.
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly COMPOSE_FILE="$(cd "${SCRIPT_DIR}/.." && pwd)/compose.yaml"

# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

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

# Polls compose services until all report healthy or timeout elapses.
#
# Arguments:
#   $1 — timeout in seconds (default: 60)
# Globals:
#   COMPOSE_FILE — read, path to compose.yaml
# Outputs:
#   Writes progress/warnings to stderr via log()
# Returns:
#   0 always (timeout is non-fatal)
wait_for_healthy() {
  local timeout="${1:-60}"
  log "Waiting up to ${timeout}s for services to be healthy..."
  local elapsed=0
  while ((elapsed < timeout)); do
    local starting
    starting="$(docker compose -f "${COMPOSE_FILE}" ps --format json 2>/dev/null \
      | grep -c '"starting"' || true)"
    if [[ "$starting" -eq 0 ]] && ((elapsed > 5)); then
      log "All services healthy"
      return 0
    fi
    sleep 3
    ((elapsed += 3))
  done
  log "WARNING: Timed out waiting for healthy services"
  return 0
}

# Entry point: starts compose services and waits for health.
#
# Outputs:
#   Writes progress to stderr via log()
main() {
  if ! has_cmd docker; then
    log "Docker not available, skipping service startup"
    return 0
  fi

  if [[ ! -f "${COMPOSE_FILE}" ]]; then
    log "No compose.yaml found, skipping service startup"
    return 0
  fi

  log "Starting compose services..."
  docker compose -f "${COMPOSE_FILE}" up -d --remove-orphans

  wait_for_healthy 60

  log "Running services:"
  docker compose -f "${COMPOSE_FILE}" ps
}

main "$@"
