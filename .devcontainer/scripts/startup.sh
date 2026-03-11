#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

COMPOSE_DIR="${SCRIPT_DIR}/../"

wait_for_healthy() {
  local timeout="${1:-60}"
  log "Waiting up to ${timeout}s for services to be healthy..."
  local elapsed=0
  while ((elapsed < timeout)); do
    if docker compose -f "${COMPOSE_DIR}/docker-compose.yml" ps --status running 2>/dev/null | grep -q "healthy"; then
      log "All services healthy"
      return 0
    fi
    # Check if any services are still starting (not yet healthy or unhealthy)
    local starting
    starting="$(docker compose -f "${COMPOSE_DIR}/docker-compose.yml" ps --format json 2>/dev/null | grep -c '"starting"' || true)"
    if [[ "$starting" -eq 0 ]] && ((elapsed > 5)); then
      log "All services settled"
      return 0
    fi
    sleep 3
    ((elapsed += 3))
  done
  log "WARNING: Timed out waiting for healthy services"
  return 0
}

main() {
  if ! has_cmd docker; then
    log "Docker not available, skipping service startup"
    return 0
  fi

  if [[ ! -f "${COMPOSE_DIR}/docker-compose.yml" ]]; then
    log "No docker-compose.yml found, skipping service startup"
    return 0
  fi

  log "Starting compose services..."
  docker compose -f "${COMPOSE_DIR}/docker-compose.yml" up -d --remove-orphans

  wait_for_healthy 60

  log "Running services:"
  docker compose -f "${COMPOSE_DIR}/docker-compose.yml" ps
}

main "$@"
