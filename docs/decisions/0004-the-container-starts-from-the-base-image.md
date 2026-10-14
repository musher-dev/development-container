---
title: The container starts from the Microsoft base image, and mise comes from a local Feature
date: 2026-10-14
status: accepted
deciders: ["@justinmerrell"]
supersedes: ["0001", "0003"]
---

# 0004 — The container starts from the Microsoft base image, and mise comes from a local Feature

## Context

[0001](0001-the-scaffold-is-published-as-a-pinned-image.md) published the scaffold as
`ghcr.io/musher-dev/development-container`, built from `.devcontainer/image/`, so a repository would pin an image
instead of copying the configuration. No release was ever cut and the package does not exist: every repository in
the organization copied the template and builds from source. The image was cost without a consumer — a second
`devcontainer.json`, a Dockerfile, release-please, a release workflow and App, a tag ruleset, and scripts that had to
run both baked into the image and from the workspace.

[0003](0003-the-image-bakes-only-mise.md) baked mise in that Dockerfile. Without the Dockerfile, mise needs another
build-time home. The one published mise Feature, `ghcr.io/devcontainers-extra/features/mise`, resolves every version
through unauthenticated `api.github.com` calls (via nanolayer's `gh-release`), the rate limit that 0003 moved bun, uv
and task off Features to avoid; its collection's maintainer has also announced cutting it back to core Features.

## Decision

We will build the dev container from `mcr.microsoft.com/devcontainers/base:ubuntu-24.04`, the Features in
`.devcontainer/devcontainer.json` and the lifecycle scripts in `.devcontainer/scripts/`, and publish nothing. mise
comes from the local Feature `.devcontainer/features/mise/`, which runs the pinned `mise.run` installer — a direct
release download, no API call — at the configuration's `min_version`. Every other CLI stays a locked pin in
`.config/mise/config.toml`, and the general rules stay in engineering-conventions, as 0003 and 0001 decided.

## Consequences

### Positive

- One `devcontainer.json`, no Dockerfile, no release machinery; the scripts run from one place only.
- A script edit takes effect on the next create, with no image to rebuild and republish.
- Building mise still makes no `api.github.com` call.

### Negative

- A repository takes the template once and does not receive later changes; it ports them by hand.
- Dependabot raises Features but not the base image tag or the local Feature; both are bumped by hand.

### Neutral

- engineering-conventions asks nothing of a repository that publishes nothing: no `outputs.toml` (OUT-01), no
  release-please configuration (REL-01), no tag ruleset.
- `.repo/` stays in a new repository: post-create installs the `repo` CLI from it.

## Enforcement

- `verify-toolchain.sh`, the Validate workflow's Devcontainer Build `runCmd`, fails when `mise --version` differs
  from `min_version`, so the Feature's `version` cannot drift (TOOL-04).
- DEVC-04 holds the base image to a fixed tag; DEVC-10 is the Dev Container Lockfiles job.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| A | Keep the published image (0001) | rejected: no consumer, and the most machinery in the repository |
| B | Base image, `devcontainers-extra/features/mise` | rejected: an unauthenticated API call on every build |
| C | Base image, mise installed by post-create | rejected: mise absent at build time, and installed per create |
| D | Base image, a local mise Feature | **chosen** |

## References

- [0001](0001-the-scaffold-is-published-as-a-pinned-image.md), [0003](0003-the-image-bakes-only-mise.md)
- [configuration.md → "The mise Feature"](../configuration.md#the-mise-feature)
