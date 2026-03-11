# Musher Dev Container Template

Canonical dev container template for the musher-dev organization. Batteries-included configuration with AI CLIs, multiple language runtimes, Docker-in-Docker, Task runner, and consistent VS Code settings. Comment out what you don't need.

## Quick Start

Copy the `.devcontainer/` directory into your repo:

```bash
cp -r .devcontainer/ /path/to/your-repo/
```

Open in VS Code → **Reopen in Container**. Out of the box you get:

- Ubuntu base with zsh/oh-my-zsh
- Node, Python, Go runtimes
- Docker-in-Docker
- Git + GitHub CLI
- Claude CLI + Codex CLI + Task runner
- GitLens, YAML, TOML, Copilot, Go, Python, Ruff, ESLint, Docker extensions
- Format on save, rulers, trailing whitespace trimming

## Architecture

```
post-create.sh          ← Entry point (repo-specific customization here)
  └── base-setup.sh     ← Reusable orchestrator (AI CLIs, Task, NVM, config dirs)
        └── common.sh   ← Shared utilities (log, retry, has_cmd, ensure_writable_dir)
```

Each layer sources the one below it. Repos customize by editing `post-create.sh` to add steps after `base_setup`, or by calling individual `base_*` functions for finer control.

## Customization

### Comment out what you don't need

The `devcontainer.json` includes everything by default. If your project doesn't use Go, comment out the Go feature and extension:

```jsonc
// "ghcr.io/devcontainers/features/go:1": {},
```

```jsonc
// "golang.go",
```

### Enable optional services

Optional services (Redis, MinIO, OCI Registry, Azimutt, Observability) are controlled via Compose profiles. Set `COMPOSE_PROFILES` in `.devcontainer/.env`:

```env
COMPOSE_PROFILES=redis,minio
```

See [CONFIGURATION.md](CONFIGURATION.md) for the full configuration reference.

### Docker Compose Services

Services run inside Docker-in-Docker via a `compose/` folder and `startup.sh`. This matches the pattern used across musher-dev repos (see [musher-dev/platform](https://github.com/musher-dev/platform) for a mature example).

```
.devcontainer/
  docker-compose.yml    ← Orchestrator (includes compose/*.yml)
  .env.example          ← Environment template (credentials, profiles)
  compose/
    postgres.yml        ← PostgreSQL with pgvector
    redis.yml           ← Redis (profile-gated)
    minio.yml           ← MinIO S3 storage (profile-gated)
    registry.yml        ← OCI Registry (profile-gated)
    azimutt.yml         ← DB explorer UI (profile-gated)
    observability.yml   ← Grafana/Tempo/Loki/OTel stack (profile-gated)
  config/
    postgres/           ← SQL init scripts mounted into PostgreSQL
    observability/      ← OTel, Grafana, Tempo, Loki config
    shell/              ← Shell aliases and functions (*.sh sourced by zsh)
  scripts/
    startup.sh          ← Starts services on every container start
    post-create.sh      ← Installs tools once on container creation
```

**Lifecycle:** `post-create.sh` runs once when the container is created (tool installs, permissions). `startup.sh` runs on every container start via `postStartCommand` (brings up compose services, waits for health checks).

**Adding a service:** Create a new file in `compose/`, add it to `docker-compose.yml`'s `include:` list, and optionally gate it with a profile. Add port forwarding in `devcontainer.json` as needed.

### Adding volumes

Follow the naming convention `musher-${localWorkspaceFolderBasename}-<purpose>`:

```jsonc
"source=musher-${localWorkspaceFolderBasename}-my-tool,target=/home/vscode/.my-tool,type=volume"
```

### Adding repo-specific setup

Edit `.devcontainer/scripts/post-create.sh` to add steps after `base_setup`:

```bash
main() {
  log "Starting post-create setup..."
  base_setup

  # --- Repo-specific setup ---
  log "Installing project dependencies..."
  npm install
  git lfs install

  log "Post-create setup completed"
}
```

### Skipping base steps

Call individual functions instead of `base_setup`:

```bash
main() {
  log "Starting post-create setup..."
  base_setup_config_dirs
  base_fix_nvm_permissions
  base_install_task
  base_install_claude
  # Skip codex: base_install_codex
  base_verify_tools
  log "Post-create setup completed"
}
```

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
