# Musher Dev Container Template

Canonical dev container template for the musher-dev organization. Batteries-included configuration with AI CLIs, multiple language runtimes, Docker-in-Docker, Task runner, and consistent VS Code settings. Comment out what you don't need.

## What You Get

- Ubuntu base with zsh/oh-my-zsh
- Node, Python, Go runtimes
- Docker-in-Docker
- Git + GitHub CLI
- Claude CLI + Codex CLI + Task runner
- GitLens, YAML, TOML, Copilot, Go, Python, Ruff, ESLint, Docker extensions
- Format on save, rulers, trailing whitespace trimming

## Usage

1. Click **Use this template** → **Create a new repository** on GitHub
2. Clone your new repo and open in VS Code
3. **Command Palette** → **Dev Containers: Reopen in Container**
4. *(Optional)* Copy `.devcontainer/.env.example` → `.devcontainer/.env` and set `COMPOSE_PROFILES` for optional services

## Customize

- Comment out unneeded features/extensions in `devcontainer.json`
- Add project setup to `scripts/post-create.sh` (runs after `base_setup`)
- Enable optional services via `COMPOSE_PROFILES` in `.devcontainer/.env` (redis, minio, registry, azimutt, observability)
- Full reference → [CONFIGURATION.md](CONFIGURATION.md)

## Included CI

This template includes `.github/workflows/validate.yaml` which runs ShellCheck, Compose config validation, and a devcontainer build check. Keep or remove per your project's needs.

## Troubleshooting

### CRLF / WSL line ending issues

The `postCreateCommand` automatically strips `\r` from all scripts before running them. If you add new scripts, ensure they're under `.devcontainer/scripts/` to be included.

### Stale containers

If settings aren't applying after changes, rebuild without cache:

**Command Palette** → **Dev Containers: Rebuild Container Without Cache**

### Volume permission errors

Named volumes may initialize with root ownership. The `ensure_writable_dir` function in `common.sh` and the `base_setup_config_dirs` step handle this for base volumes. For custom volumes, call `ensure_writable_dir` in your `post-create.sh`:

```bash
ensure_writable_dir /home/vscode/.my-tool
```

### Tool installation failures

Base setup uses `retry` with 3 attempts and 5-second delays for network operations. If a tool consistently fails to install, check network connectivity and try rebuilding the container.
