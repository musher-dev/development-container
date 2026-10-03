---
title: The image bakes only mise; every other CLI is a locked mise pin
date: 2026-10-03
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
---

# 0003 — The image bakes only mise; every other CLI is a locked mise pin

## Context

bun, uv and task were baked into the Dockerfile with pinned `ARG`s because their Features resolve release assets
through unauthenticated `api.github.com` calls, which the shared egress IPs of Codespaces and CI rate-limit. A local
check (TC-01..03) kept them out of `devcontainer.json` and in step with CI.

engineering-conventions' toolchain convention puts every pin in one mise configuration,
`.config/mise/config.toml` (TOOL-01), with a committed `mise.lock` (TOOL-05), and supersedes baking.

## Decision

We will bake only mise, at `ARG MISE_VERSION` equal to the configuration's `min_version` (TOOL-04), and pin bun,
uv, task and every other CLI in `.config/mise/config.toml`. post-create runs `mise install --locked`.

## Consequences

### Positive

- One file pins every CLI, locally and in CI (`jdx/mise-action`).
- `mise.lock` records each download URL and checksum, so `install --locked` makes none of the API calls that
  rate-limited the Features.

### Negative

- bun, uv and task arrive at post-create rather than at build, so a step that runs before post-create cannot use
  them.

### Neutral

- TC-01..03 are retired.

## Enforcement

- TOOL-01, TOOL-04 and TOOL-05 in `conventions check`.
- `verify-toolchain.sh` (the Validate workflow's Devcontainer Build) fails when mise is not the pinned version or
  a mise pin is not installed.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| A | Keep baking bun, uv and task | rejected: two pin locations, superseded upstream |
| B | Locked mise pins | **chosen** |

## References

- musher-dev/development-container#27, step 2
