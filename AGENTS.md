# Musher dev container — agent-facing notes

@README.md

Agent-facing contract for `musher-dev/development-container`. The `@README.md` line above is a Claude Code import;
another agent opens [README.md](README.md) directly. The README carries the orientation; this file carries only what
constrains a change. There is no `CLAUDE.md` (AGENT-16).

- Where a file goes: [docs/layout.md](docs/layout.md) and [docs/configuration.md](docs/configuration.md).
- Why the repository is shaped the way it is: [docs/decisions/](docs/decisions/).

## Hard lines

- **The dev container is the product.** `.devcontainer/` is what every new repository starts from: the Microsoft base
  image, pinned Features and the lifecycle scripts in `.devcontainer/scripts/`. There is no image of our own and no
  release ([decision 0004](docs/decisions/0004-the-container-starts-from-the-base-image.md)).
- **One place per pin.** Features in `devcontainer.json`; every other CLI in `.config/mise/config.toml`, followed by
  `mise lock`. mise itself comes from the local Feature in `.devcontainer/features/mise/`, at the configuration's
  `min_version`.
- **No committed environment file.** `.devcontainer/env.schema.yaml` is the source; `repo env sync` writes `.env`.
- **General rules belong upstream.** A rule about any repository goes to engineering-conventions, not to `.repo/`.

## Verification

`task check` runs every gate CI runs except ShellCheck, the dev container builds and the compose validation.

## Commits

Conventional Commits, enforced by committed at commit-msg and on the PR title. Types and scopes are in
[`.config/commits/committed.toml`](.config/commits/committed.toml).
