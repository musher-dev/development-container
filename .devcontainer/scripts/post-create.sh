#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"
# shellcheck source=base-setup.sh
source "${SCRIPT_DIR}/base-setup.sh"

main() {
  log "Starting post-create setup..."
  base_setup
  # --- Add repo-specific setup below ---
  log "Post-create setup completed"
}

main "$@"
