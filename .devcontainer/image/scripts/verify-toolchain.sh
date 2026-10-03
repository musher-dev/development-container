#!/usr/bin/env bash
# verify-toolchain.sh — Asserts the built container carries the pinned toolchain.
#
# Two halves. The image bakes only mise, and the Dockerfile's assertion is
# presence-only (`test -x`): executing a binary in the layer that installed it
# is a known BuildKit hazard. So this checks mise reports the ARG MISE_VERSION
# pin, read back out of the Dockerfile so the ARG stays the single source.
# Everything else is a mise pin that post-create installed; `mise ls --missing`
# proves every one of them is there.
#
# Usage: bash .devcontainer/image/scripts/verify-toolchain.sh
#        (CI runs it as the devcontainers/ci `runCmd`, from the workspace.)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
DOCKERFILE="${SCRIPT_DIR}/../Dockerfile"
readonly DOCKERFILE

# Reads a pinned ARG default out of the Dockerfile.
#
# Arguments:
#   $1 — the ARG name, e.g. BUN_VERSION
# Outputs:
#   The pinned value on stdout
# Returns:
#   0 on success, 1 if the ARG is absent or has no default
arg_pin() {
  local name="${1}"
  local value
  value="$(sed -n "s/^ARG ${name}=\\(.*\\)$/\\1/p" "${DOCKERFILE}" | head -1)"
  if [[ -z "${value}" ]]; then
    echo "ERROR: no 'ARG ${name}=<pin>' in ${DOCKERFILE}" >&2
    return 1
  fi
  printf '%s\n' "${value}"
}

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

# Entry point: checks mise against its Dockerfile pin, then the mise pins.
#
# Outputs:
#   Writes per-tool results to stdout
# Returns:
#   0 if everything matches, 1 otherwise
main() {
  echo "Verifying the toolchain against ${DOCKERFILE} and the mise config..."

  # MISE_VERSION is pinned with a leading 'v'; `mise --version` prints without.
  local mise_v failed=0
  mise_v="$(arg_pin MISE_VERSION)"
  assert_version mise "${mise_v#v}" || failed=1

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
