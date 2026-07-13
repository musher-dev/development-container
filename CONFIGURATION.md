# Configuration Guide

**Philosophy: One need, one place.** Every configuration concern maps to exactly one canonical location. If you're unsure where something goes, use the decision tree below.

## Decision Tree

```
Where does my configuration go?

Runtime, or any tool that has a devcontainer Feature?
  → devcontainer.json → features block (pin the version)

CLI with no Feature (npm-distributed, e.g. codex, lefthook)?
  → .devcontainer/mise.toml

Self-updating CLI (e.g. Claude Code)?
  → scripts/lib/base-setup.sh (native installer)

Infrastructure service (DB, cache, queue, storage)?
  → stacks/<name>/compose.yaml (new folder, add to compose.yaml includes)

VS Code editor behavior or extension?
  → devcontainer.json → customizations.vscode block

Credential or per-developer toggle?
  → .devcontainer/.env (auto-created from .env.example on first build)

Service-internal configuration (tuning, pipelines)?
  → stacks/<name>/ (colocated with that stack's compose.yaml)

One-time setup step?
  → scripts/post-create.sh

Runs on every container start?
  → scripts/startup.sh
```

## Quick Reference

| Category | Need | Canonical Location |
|---|---|---|
| **Runtimes & Tools** | Anything with a Feature (Node, Python, Go, Java, Deno, bun, uv, gh, Task, ShellCheck) | `devcontainer.json` → `features` (pinned) |
| | CLIs with no Feature (Codex, Lefthook) | `.devcontainer/mise.toml` |
| | Self-updating CLIs (Claude Code) | `scripts/lib/base-setup.sh` |
| **Editor** | VS Code settings (formatters, rulers, whitespace) | `devcontainer.json` → `customizations.vscode.settings` |
| | VS Code extensions | `devcontainer.json` → `customizations.vscode.extensions` |
| | Debug launch configs | `.vscode/launch.json` (in consuming project) |
| **Shell & User** | Default shell, prompt, oh-my-zsh config | `devcontainer.json` → `common-utils` feature |
| | Git config | Host `.gitconfig` (auto-forwarded by devcontainers) |
| | Git hooks | Project repo (`.husky/` or `.githooks/`) |
| **Environment** | Runtime behavior vars (`PYTHONUNBUFFERED`, etc.) | `devcontainer.json` → `containerEnv` |
| | PATH extensions | `devcontainer.json` → `remoteEnv` |
| | Service credentials (dev-only) | `.devcontainer/.env` |
| | Service profiles/toggles | `.devcontainer/.env` → `COMPOSE_PROFILES` |
| | Secrets (API keys, tokens) | Host env forwarded via `remoteEnv` — never committed |
| **Services** | Infrastructure services | `.devcontainer/stacks/<name>/compose.yaml` |
| | Service enable/disable | `.devcontainer/.env` → `COMPOSE_PROFILES` |
| | Service tuning/config | `.devcontainer/stacks/<name>/` (colocated) |
| **Networking** | Port allocation (container-side) | `.devcontainer/stacks/<name>/compose.yaml` → `ports:` |
| | Port forwarding (to host IDE) | `devcontainer.json` → `forwardPorts` + `portsAttributes` |
| | Service discovery | Automatic via Docker Compose `musher-dev` network |
| **Observability** | Telemetry pipeline config | `.devcontainer/stacks/observability/config/otel-collector-config.yaml` |
| | Grafana dashboards | `.devcontainer/stacks/observability/config/grafana/provisioning/dashboards/json/` |
| | Grafana datasources | `.devcontainer/stacks/observability/config/grafana/provisioning/datasources/` |
| **Data** | DB schema init (base) | `.devcontainer/stacks/postgres/init/00-init.sql` |
| | DB schema init (project) | `.devcontainer/stacks/postgres/init/01-project.sql` |
| | DB migrations | Project tooling (Atlas, Flyway — not in template) |
| | Data persistence | Compose files → named volumes |
| **Lifecycle** | One-time container setup | `scripts/post-create.sh` → `lib/base-setup.sh` |
| | Every-start tasks | `scripts/startup.sh` |
| | Task automation | `Taskfile.yml` (in consuming project) |
| **AI Tools** | Claude Code (native installer) | `lib/base-setup.sh` |
| | Codex CLI (pinned) | `.devcontainer/mise.toml` |
| | AI CLI config persistence | `devcontainer.json` → `mounts` (named volumes) |
| **Security** | Container capabilities | `devcontainer.json` → `capAdd` / `securityOpt` |
| | Network binding | Compose files → all ports bound to `127.0.0.1` |

---

## Runtimes & Tools

Tools land in one of three places. **Prefer a Feature** — if one exists, pin its version there.

### 1. Tools with a Feature → `devcontainer.json`

Runtimes and any CLI that ships a devcontainer Feature are pinned in the `features` block, so they're baked into the image:

```jsonc
"features": {
  "ghcr.io/devcontainers/features/node:1": { "version": "24.18.0" },
  "ghcr.io/devcontainers/features/python:1": { "version": "3.13.14" },
  "ghcr.io/devcontainers-extra/features/deno:1": { "version": "2.9.2" }
}
```

Comment out any tool you don't need (and its matching VS Code extension). Pin an exact version where the Feature supports it; a couple track a major line instead (`java: 17`, `postgresql-client: 16`).

### 2. CLIs with no Feature → `.devcontainer/mise.toml`

npm-distributed CLIs like Codex and Lefthook have no Feature, so [mise](https://mise.jdx.dev) pins and installs them. Add a line under `[tools]`:

```toml
[tools]
"npm:@openai/codex" = "0.143.0"
"npm:lefthook"      = "2.1.10"
```

`mise install` runs in post-create; re-run it (or `task tools:install`) after editing.

### 3. Self-updating CLIs → `scripts/lib/base-setup.sh`

CLIs that manage their own updates (Claude Code) install via their native installer. Add a function and call it from `base_setup()`:

```bash
base_install_mytool() {
  has_cmd mytool && return 0
  log "Installing mytool..."
  retry 3 5 bash -c 'curl -fsSL https://mytool.dev/install.sh | bash'
}
```

---

## Editor

### VS Code Settings

All editor settings live in `devcontainer.json` → `customizations.vscode.settings`. Do not create a `.vscode/settings.json` in the template — that's for consuming projects.

### VS Code Extensions

All extensions live in `devcontainer.json` → `customizations.vscode.extensions`. Comment out extensions for runtimes you don't use.

---

## Shell & User

### Git Config

Git config is auto-forwarded from your host machine by the devcontainer CLI. No configuration needed in the template.

---

## Environment Variables

There are four distinct scopes for environment variables. Use the right one:

| Scope | Location | When to Use |
|---|---|---|
| **Container-wide** | `devcontainer.json` → `containerEnv` | Runtime behavior (`PYTHONUNBUFFERED`, `UV_LINK_MODE`) |
| **Remote/IDE** | `devcontainer.json` → `remoteEnv` | PATH extensions, forwarded host secrets |
| **Compose services** | `.devcontainer/.env` | Service credentials, `COMPOSE_PROFILES` |
| **Service-specific** | `stacks/<name>/compose.yaml` → `environment:` | Internal service config (uses `${VAR:-default}` interpolation) |

### Secrets

Never commit secrets. Forward them from your host environment:

```jsonc
"remoteEnv": {
  "MY_API_KEY": "${localEnv:MY_API_KEY}"
}
```

### Service Credentials

Dev-only credentials live in `.devcontainer/.env` (gitignored). The host-side `initializeCommand` (`scripts/initialize.sh`) copies `.env.example` → `.env` on first build, so `runArgs --env-file` has a valid file to load. The same file is also auto-discovered by Docker Compose. To reset, delete `.devcontainer/.env` and rebuild — or run `task env:reset`.

The template follows a three-state grammar:

| State | Syntax | Meaning |
|---|---|---|
| Filled default | `VAR=value` | Safe demo value; override only if you need something different. |
| Required (empty) | `VAR=` | Must be filled in; the MOTD warns at container start until set. |
| Optional override | `# VAR=value` | Uncomment to enable. |

---

## Services

### Enabling/Disabling Services

All services are included in `compose.yaml`. Optional services are gated by Compose profiles:

| Service | Profile | Always On? |
|---|---|---|
| PostgreSQL | — | Yes |
| Redis | `redis` | No |
| MinIO | `minio` | No |
| OCI Registry | `registry` | No |
| Azimutt | `azimutt` | No |
| Observability stack | `observability` | No |

Enable services by setting `COMPOSE_PROFILES` in `.devcontainer/.env`:

```env
COMPOSE_PROFILES=redis,minio,observability
```

### Adding a New Service

1. Create `stacks/myservice/compose.yaml`
2. Add `- stacks/myservice/compose.yaml` to `compose.yaml` `include:`
3. Optionally add `profiles: [myservice]` if it should be opt-in
4. Add port forwarding in `devcontainer.json` → `forwardPorts` and `portsAttributes`
5. Use `${VAR:-default}` for any credentials, and add them to `.env.example`

### Service Configuration

Each stack owns its config: put a stack's config files inside its own folder,
next to that stack's `compose.yaml`, and bind-mount them with a path relative to
the stack folder (e.g. `./init`, `./config/...`):

```
stacks/
  postgres/
    compose.yaml
    init/               SQL init scripts (mounted at ./init)
  observability/
    compose.yaml
    config/             OTel, Grafana, Tempo, Loki configs (mounted at ./config)
```

---

## Networking

### Port Allocation

All ports are bound to `127.0.0.1` (localhost only) for security. The template uses the `154xx` range:

| Port | Service | Protocol |
|---|---|---|
| 15432 | PostgreSQL | TCP |
| 15433 | Redis | TCP |
| 15434 | MinIO API | HTTP |
| 15435 | MinIO Console | HTTP |
| 15436 | OCI Registry | HTTP |
| 15440 | MinIO API (Observability) | HTTP |
| 15441 | MinIO Console (Observability) | HTTP |
| 15442 | Tempo | HTTP |
| 15443 | Loki | HTTP |
| 15444 | VictoriaMetrics | HTTP |
| 15445 | OTel Collector HTTP | HTTP |
| 15446 | OTel Collector gRPC | gRPC |
| 15447 | Grafana | HTTP |
| 15448 | Pyroscope | HTTP |
| 15460 | Azimutt | HTTP |

### Service Discovery

Services communicate via the `musher-dev` Docker network. Use the service name as the hostname (e.g., `postgres`, `redis`, `minio-observability`) with the container-internal port.

---

## Observability

The observability stack is profile-gated (`COMPOSE_PROFILES=observability`). It includes:

- **Grafana** — Dashboards and visualization (port 15447)
- **Tempo** — Distributed tracing backend
- **Loki** — Log aggregation
- **VictoriaMetrics** — Metrics storage
- **OTel Collector** — Telemetry pipeline (receives OTLP on ports 15445/15446)
- **Pyroscope** — Continuous profiling
- **MinIO (Observability)** — Object storage for Tempo and Loki

### Configuration Files

| File | Purpose |
|---|---|
| `stacks/observability/config/otel-collector-config.yaml` | OTel Collector pipeline configuration |
| `stacks/observability/config/tempo-config.yaml` | Tempo storage and ingestion config |
| `stacks/observability/config/loki-config.yaml` | Loki storage and ingestion config |
| `stacks/observability/config/grafana/provisioning/datasources/` | Auto-provisioned Grafana datasources |
| `stacks/observability/config/grafana/provisioning/dashboards/json/` | Auto-provisioned Grafana dashboards |

> **Note:** `tempo-config.yaml` and `loki-config.yaml` contain hardcoded MinIO credentials because they are native YAML configs that don't support environment variable interpolation. If you change `MINIO_OBS_ROOT_USER` or `MINIO_OBS_ROOT_PASSWORD` in `.env`, you must also update these files to match.

---

## Data

### Database Initialization

SQL files in `.devcontainer/stacks/postgres/init/` are mounted into PostgreSQL's `docker-entrypoint-initdb.d/` and run in alphabetical order on first container creation:

- `00-init.sql` — Base schema (extensions, shared types)
- `01-project.sql.example` — Project-specific schema (copy to `01-project.sql`)

### Persistence

All services use named Docker volumes (e.g., `musher-postgres-data`). Data persists across container restarts but is lost on full rebuild. For migrations, use project-level tooling (Atlas, Flyway, etc.).

### Adding Volumes

Follow the naming convention `musher-${devcontainerId}-<purpose>`:

```jsonc
"source=musher-${devcontainerId}-my-tool,target=/home/vscode/.my-tool,type=volume"
```

---

## Lifecycle

| Hook | Runs | Use For |
|---|---|---|
| `initializeCommand` | Host-side, before every `docker run` | Bootstrap that must exist before the container starts (e.g., creating `.devcontainer/.env` so `--env-file` works) |
| `postCreateCommand` | Once, on container creation | Tool installation, permissions, lefthook hooks |
| `postStartCommand` | Every container start | `docker compose up`, health checks |

### Skipping Base Steps

Call individual functions instead of `base_setup`:

```bash
main() {
  log "Starting post-create setup..."
  base_setup_config_dirs
  base_setup_cache_dirs
  base_fix_nvm_permissions
  base_setup_path
  base_install_mise
  # Skip the mise CLIs: base_install_tools
  base_install_claude
  base_verify_tools
  log "Post-create setup completed"
}
```

### Script Layers

```
post-create.sh              ← Entry point (repo-specific customization)
  └── lib/base-setup.sh     ← Reusable orchestrator (mise CLIs, Claude, nvm, config/cache dirs)
        └── lib/common.sh   ← Shared utilities (log, retry, has_cmd, ensure_writable_dir)
```

---

## AI Tools

### Installed CLIs

- **Claude Code** — native self-updating installer (`base-setup.sh`), config persisted in the `~/.claude` volume
- **Codex CLI** — pinned in `.devcontainer/mise.toml`, config persisted in the `~/.codex` volume

### Configuration Persistence

AI CLI configs are stored in named volumes mounted via `devcontainer.json` → `mounts`. This preserves authentication and settings across container rebuilds.

---

## Directory Map

```
.devcontainer/
  devcontainer.json           Features, extensions, settings, mounts, ports
  mise.toml                   CLIs without a Feature (codex, lefthook)
  compose.yaml                Stack orchestrator (includes stacks/<name>/compose.yaml)
  .env.example                Environment template (copy to .env)
  .env                        Local overrides (gitignored)
  stacks/                     One folder per stack: its compose.yaml + colocated config
    postgres/
      compose.yaml             PostgreSQL with pgvector (always on)
      init/
        00-init.sql            Base DB schema
        01-project.sql.example Project schema template
    redis/
      compose.yaml             Redis (profile: redis)
    minio/
      compose.yaml             MinIO S3 storage (profile: minio)
    registry/
      compose.yaml             OCI Registry (profile: registry)
    azimutt/
      compose.yaml             DB explorer UI (profile: azimutt)
    observability/
      compose.yaml             Full observability stack (profile: observability)
      config/
        otel-collector-config.yaml
        tempo-config.yaml
        loki-config.yaml
        grafana/provisioning/
          datasources/         Auto-provisioned datasources
          dashboards/json/     Auto-provisioned dashboards
  scripts/
    initialize.sh             Host-side bootstrap (runs before docker run)
    post-create.sh            One-time setup entry point
    startup.sh                Every-start service launcher
    lib/
      base-setup.sh           Reusable tool installer (mise CLIs + Claude)
      common.sh               Shared utilities
      env-check.sh            .env / .env.example drift detection
      motd.sh                 Startup MOTD renderer
```
