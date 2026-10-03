# Musher dev container — agent-facing notes

@README.md

Agent-facing contract for `musher-dev/development-container`. The `@README.md` line above is a Claude Code import;
another agent opens [README.md](README.md) directly. The README carries the orientation; this file carries only what
constrains a change. There is no `CLAUDE.md` (AGENT-16).

- Where a file goes: [LAYOUT.md](LAYOUT.md) and [CONFIGURATION.md](CONFIGURATION.md).
- Why the repository is shaped the way it is: [docs/decisions/](docs/decisions/).

## Hard lines

- **The image is the product.** `.devcontainer/image/` is what a release publishes; a change there is a change for
  every consuming repository. Its scripts run both from the workspace and baked at
  `/usr/local/share/musher-devcontainer/`, so they resolve the workspace with `workspace_root`, never from their own
  path.
- **One place per pin.** Features in `devcontainer.json`; every other CLI in `.config/mise/config.toml`, followed by
  `mise lock`. The Dockerfile bakes only mise, at the configuration's `min_version`.
- **No committed environment file.** `.devcontainer/env.schema.yaml` is the source; `repo env sync` writes `.env`.
- **General rules belong upstream.** A rule about any repository goes to engineering-conventions, not to `.repo/`.

## Verification

`task check` runs every gate CI runs except the dev container builds and the compose validation.

## Commits

Conventional Commits, enforced by committed at commit-msg and on the PR title. Types and scopes are in
[`.config/commits/committed.toml`](.config/commits/committed.toml). The commit type is the release: `feat` and `fix`
cut one.
