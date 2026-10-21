#!/usr/bin/env bash
# npm-registry.sh — Library: give bun a GitHub Packages credential for @musher-dev/*.
#
# Canonical copy: musher-dev/development-container
# .devcontainer/scripts/lib/npm-registry.sh. Repositories copy it verbatim and
# change it here first. The template itself installs no @musher-dev/* package;
# it ships this for repositories whose .npmrc routes that scope to GitHub
# Packages. Sourced, never executed.
#
# The registry wants a token even for a public package, and bun looks it up in
# the user's own .npmrc, never the repository's, so no token is ever committed.
#   npm_registry_setup  post-create and post-attach: never prompts, and skips
#                       while gh has no token with read:packages.
#   npm_registry_auth   `task setup:registry`: asks gh for read:packages when
#                       the token lacks it, then writes the line.
#
# Exposes:
#   npm_registry_file, npm_registry_configured, npm_registry_setup, npm_registry_auth

if [[ -z "${_MUSHER_NPM_REGISTRY_LOADED:-}" ]]; then
_MUSHER_NPM_REGISTRY_LOADED=1

_NPM_REGISTRY_HOST="npm.pkg.github.com"

_npm_log() {
  printf 'npm-registry: %s\n' "$*" >&2
}

# bun reads $XDG_CONFIG_HOME/.npmrc when that variable is set and $HOME/.npmrc
# otherwise, with no fallback between the two.
npm_registry_file() {
  printf '%s/.npmrc\n' "${XDG_CONFIG_HOME:-${HOME}}"
}

npm_registry_configured() {
  grep -qsE "^//${_NPM_REGISTRY_HOST}/:_authToken=.+" "$(npm_registry_file)"
}

# Whether gh's active account holds a token with a packages scope. Captured,
# not piped into `grep -q`, whose early exit SIGPIPEs gh under pipefail.
_npm_gh_reads_packages() {
  local status
  status="$(gh auth status --active --hostname github.com 2>&1)" || return 1
  grep -qE "'(read|write):packages'" <<<"${status}"
}

# The value to write. With an env token (Codespaces) a reference that bun
# expands when it reads the file, so a re-issued token never goes stale;
# otherwise gh's stored token, and nothing when gh returns none.
_npm_registry_value() {
  # shellcheck disable=SC2016  # the reference is written literally, for bun
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    printf '%s' '${GITHUB_TOKEN}'
  elif [[ -n "${GH_TOKEN:-}" ]]; then
    printf '%s' '${GH_TOKEN}'
  else
    local token
    token="$(gh auth token --hostname github.com 2>/dev/null)" || return 1
    [[ -n "${token}" ]] || return 1
    printf '%s' "${token}"
  fi
}

# Replaces any earlier line for the host and keeps every other line. The file
# is never world-readable, and the temporary copy never outlives the call.
_npm_registry_write() {
  local value="$1" file tmp
  [[ -n "${value}" ]] || return 1
  file="$(npm_registry_file)"
  tmp="$(mktemp)"
  if [[ -f "${file}" ]]; then
    grep -v "^//${_NPM_REGISTRY_HOST}/" "${file}" >"${tmp}" || true
  fi
  printf '//%s/:_authToken=%s\n' "${_NPM_REGISTRY_HOST}" "${value}" >>"${tmp}"
  if ! install -m 600 "${tmp}" "${file}"; then
    rm -f "${tmp}"
    return 1
  fi
  rm -f "${tmp}"
}

# Writes the credential when it can do so without asking anything.
#
# Outputs:
#   Writes progress to stderr
# Returns:
#   0 always
npm_registry_setup() {
  npm_registry_configured && return 0
  local value
  if [[ -z "${GITHUB_TOKEN:-}${GH_TOKEN:-}" ]]; then
    if ! command -v gh >/dev/null 2>&1 || ! gh auth token --hostname github.com >/dev/null 2>&1; then
      _npm_log "skipped: gh is not logged in. Run 'task setup:registry' once it is."
      return 0
    fi
    if ! _npm_gh_reads_packages; then
      _npm_log "skipped: gh's token lacks read:packages. Run 'task setup:registry'."
      return 0
    fi
  fi
  if ! value="$(_npm_registry_value)" || ! _npm_registry_write "${value}"; then
    _npm_log "skipped: no token to write to $(npm_registry_file)."
    return 0
  fi
  _npm_log "bun can download @musher-dev/* from ${_NPM_REGISTRY_HOST} ($(npm_registry_file))."
  return 0
}

# `task setup:registry`: interactive when the scope is missing, because
# `gh auth login` does not ask for read:packages by default.
#
# Outputs:
#   Writes progress to stderr
# Returns:
#   0 on success, 1 when gh is missing, not logged in or refused
npm_registry_auth() {
  local value
  if [[ -z "${GITHUB_TOKEN:-}${GH_TOKEN:-}" ]]; then
    if ! command -v gh >/dev/null 2>&1; then
      _npm_log "ERROR: the GitHub CLI is required."
      return 1
    fi
    if ! gh auth token --hostname github.com >/dev/null 2>&1; then
      _npm_log "ERROR: gh is not logged in. Run 'gh auth login', then 'task setup:registry'."
      return 1
    fi
    if ! _npm_gh_reads_packages; then
      _npm_log "Requesting the read:packages scope (browser or device-code flow)..."
      gh auth refresh --hostname github.com --scopes read:packages || return 1
    fi
  fi
  if ! value="$(_npm_registry_value)" || ! _npm_registry_write "${value}"; then
    _npm_log "ERROR: could not write $(npm_registry_file)."
    return 1
  fi
  _npm_log "bun can download @musher-dev/* from ${_NPM_REGISTRY_HOST} ($(npm_registry_file))."
}

fi
