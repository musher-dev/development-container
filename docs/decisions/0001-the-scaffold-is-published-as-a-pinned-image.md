---
title: The scaffold is published as a pinned image, and the general rules live in engineering-conventions
date: 2026-10-03
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
---

# 0001 — The scaffold is published as a pinned image, and the general rules live in engineering-conventions

## Context

This repository is a GitHub template, and a template is copied once. About ten repositories carry a copy of the
scaffold, several carry a copy of the `.repo/` CLI, and nothing links a copy back: the repository had no releases
and no tags, so a consumer could record only a commit, and drift showed up as a diff nobody reads (#24, #28).

engineering-conventions now owns the rules about any repository, including its dev container files (the DEVC
family, its [decision 0020][ec-0020]), and
publishes them as versioned releases a repository pins.

## Decision

We will publish the scaffold the way the conventions are published: as a versioned artifact a repository pins.

- Each release builds `.devcontainer/image/` with the Dev Container CLI and pushes
  `ghcr.io/musher-dev/<repository>:X.Y.Z` for amd64 and arm64, with build provenance. The image carries mise, the
  platform Features, the config volumes, the cache environment and the lifecycle scripts in its
  `devcontainer.metadata` label. `.repo/outputs.toml` declares it.
- A consuming repository's `devcontainer.json` names that image at an exact version and adds only its runtimes,
  stacks and ports. Its updater raises the version.
- release-please cuts the releases, from conventional commits.
- The general rules this repository's `.repo/` CLI enforced are retired in favour of the engineering-conventions
  requirements that adopted them; the CLI keeps only what is specific to the scaffold. A repository pins
  `github:musher-dev/engineering-conventions` rather than copying `.repo/`, and the image installs the scaffold's
  `repo` CLI from the release it came from.

## Consequences

### Positive

- Drift is a version number. A consumer sees what changed in the changelog and takes it with one line.
- The general rules have one home and one release cadence.

### Negative

- Until the first release is published, this repository's own `devcontainer.json` still builds from source and
  repeats the platform Features the image definition holds.
- A scaffold change reaches a consumer only after a release.

### Neutral

- The config volumes stay per container (`musher-${devcontainerId}-...`), the only form DEVC-08 accepts.

## Enforcement

- OUT-01 and OUT-06 require the `image` output and its publishing workflow; OUT-13 the source label.
- REL-01..20 check the release-please configuration and `release.yaml`.
- DEVC-10: the Validate workflow builds both dev container configurations with `--frozen-lockfile`.
- ADOPT-09: `.config/mise/config.toml` pins the conventions release.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| A | Keep copying the scaffold; add tags so consumers can diff | rejected: a diff still nobody reads |
| B | Publish a Dev Container Feature | rejected: a Feature cannot carry the lifecycle scripts' metadata and volumes as one unit |
| C | Publish a prebuilt image and pin it | **chosen** |

## References

- musher-dev/development-container#24, #27, #28
- engineering-conventions [decision 0020][ec-0020]

[ec-0020]: https://github.com/musher-dev/engineering-conventions/blob/v0.8.0/docs/decisions/0020-dev-container-files-get-their-own-family.md
