#!/usr/bin/env bash
# env-load.sh — Library: export .devcontainer/.env into the current shell.
#
# This is a library file meant to be sourced, not executed directly.
# Usage: source "path/to/env-load.sh" [env-file]
#
# Why it exists: .devcontainer/.env is generated inside the container by
# post-create, so it is not in the container's own environment. Post-create
# wires this into the shell profile, so every new terminal (and every task run
# from it) sees the current file, edits included, without a rebuild.
#
# Why it does not `source` the file: dotenv is not shell. Compose's --env-file
# treats the whole right-hand side literally, so `FOO=a b` is one value there
# and a command execution to a shell. This parses instead.
#
# Exposes:
#   env_load [file] — export every KEY=VALUE in a dotenv file

# Exports each assignment in a dotenv file into the current shell.
#
# Arguments:
#   $1 — path to the env file (default: .devcontainer/.env in the workspace)
# Outputs:
#   None
# Returns:
#   0 always — a missing file is not an error, it is a fresh clone
env_load() {
  local file="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)/.devcontainer/.env}"
  [[ -f "${file}" ]] || return 0

  local line key value
  while IFS= read -r line || [[ -n "${line}" ]]; do
    [[ "${line}" =~ ^[[:space:]]*# ]] && continue
    [[ "${line}" =~ ^([A-Z][A-Z0-9_]*)=(.*)$ ]] || continue
    key="${BASH_REMATCH[1]}"
    # A Windows editor can leave CRLF in this gitignored file, which
    # .gitattributes cannot normalize.
    value="${BASH_REMATCH[2]%$'\r'}"
    export "${key}=${value}"
  done < "${file}"
}
