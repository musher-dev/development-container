#!/usr/bin/env bash
# version.sh — The release these scripts were published in.
#
# release-please rewrites the marked line on every release (extra-files in
# .github/release-please/config.json), so a script baked into the image knows
# which tag of this repository it came from.
# shellcheck disable=SC2034  # read by the scripts that source this file
readonly MUSHER_DEVCONTAINER_VERSION="0.0.0" # x-release-please-version
