#!/usr/bin/env bash
# verify-toolchain.sh — Asserts the built container carries the pinned toolchain.
#
# Two halves. The mise Feature installs mise at build time; this checks it
# reports the configuration's min_version, the one mise pin (TOOL-04), so a
# Feature option that drifts from it fails here. Everything else is a mise pin
# that post-create installed; `mise ls --missing` proves every one of them is
# there.
#
# Usage: bash .devcontainer/scripts/verify-toolchain.sh
#        (CI runs it as the devcontainers/ci `runCmd`, from the workspace.)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

# Asserts `<tool> --version` reports the expected version.
#
# Arguments:
#   $1 — the binary name, which is also the human-readable tool name
#   $2 — expected version (no leading 'v')
# Outputs:
#   Writes a pass/fail line to stdout
# Returns:
#   0 on match, 1 on mismatch or missing binary
assert_version() {
  local tool="${1}" expected="${2}"
  local actual
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "  FAIL ${tool}: not on PATH"
    return 1
  fi
  # Tools disagree on output shape (`task` prints "Task version: v3.52.0", uv
  # prints "uv 0.11.28"), so match the expected string anywhere in the first
  # line rather than parsing four different formats.
  actual="$("${tool}" --version 2>&1 | head -1)"
  if [[ "${actual}" != *"${expected}"* ]]; then
    echo "  FAIL ${tool}: expected ${expected}, got '${actual}'"
    return 1
  fi
  echo "  ok   ${tool} ${expected}"
}

# Entry point: checks mise against min_version, then the mise pins.
#
# Outputs:
#   Writes per-tool results to stdout
# Returns:
#   0 if everything matches, 1 otherwise
main() {
  local root mise_v failed=0
  root="$(workspace_root)"
  echo "Verifying the toolchain against ${root}/.config/mise/config.toml..."

  if mise_v="$(mise_min_version "${root}")"; then
    assert_version mise "${mise_v}" || failed=1
  else
    echo "  FAIL mise: no min_version in .config/mise/config.toml"
    failed=1
  fi

  local missing
  missing="$(mise ls --missing --no-header 2>&1)" || failed=1
  if [[ -n "${missing}" ]]; then
    echo "  FAIL mise pins not installed:"
    echo "${missing}"
    failed=1
  else
    echo "  ok   every mise pin is installed"
  fi

  if ((failed)); then
    echo "Toolchain verification FAILED" >&2
    return 1
  fi
  echo "Toolchain verification passed"
}

main "$@"
