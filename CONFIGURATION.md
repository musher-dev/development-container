# Configuration Guide

**Philosophy: One need, one place.** Every configuration concern maps to exactly one canonical location. If you're
unsure where something goes, use the decision tree below.

This guide covers the **repository level**. Whether a file belongs to the repository or to the product directory is
decided first, by [LAYOUT.md](LAYOUT.md#the-placement-test).

## Decision Tree

```text
Where does my configuration go?

Is it read by the product's native toolchain, or found by walking up from
the product (Cargo.toml, rustfmt.toml, tsconfig.json, ruff.toml)?
  → <product>/ — see LAYOUT.md. Everything below is the repository level.

Is the tool's config auto-loaded only from the repo root, with no way to
point at another path (Task)?
  → repo root. No alternative — these are orchestration entry points.

Does it configure a linter, formatter, or the git hooks?
  → .config/<concern>/<tool>.<ext> (lefthook.yml stays at .config/ top level)

Does it provision the container itself?
  → .devcontainer/ (see the branches below)

Runtime, or a tool with a Feature whose installer avoids api.github.com?
  → devcontainer.json → features block (pin the version)

Self-updating CLI (e.g. Claude Code)?
  → image/scripts/lib/base-setup.sh (native installer)

Any other CLI (bun, uv, task, codex, lefthook, linters)?
  → .config/mise/config.toml, then `mise lock`

Infrastructure service (DB, cache, queue, storage)?
  → stacks/<name>/compose.yaml (new folder, add to stacks/compose.yaml includes)

VS Code editor behavior or extension?
  → devcontainer.json → customizations.vscode block

Credential or per-developer toggle?
  → declare it in .devcontainer/env.schema.yaml (`repo env sync` writes .env)

Service-internal configuration (tuning, pipelines)?
  → stacks/<name>/ (colocated with that stack's compose.yaml)

One-time setup step?
  → image/scripts/post-create.sh, or a repository's own postCreateCommand

Runs on every container start?
  → image/scripts/startup.sh
```

## Where Configuration Lives

Four homes at the repository level, and a rule for choosing between them. Ask these in order and stop at
the first "yes".

| # | Question | Home | Examples |
| --- | --- | --- | --- |
| 1 | Can the tool *only* load from the repo root, with no flag to point elsewhere? | Repo root | `Taskfile.yml`, `.gitattributes`, `.gitignore` |
| 2 | Does it configure a tool: a linter, formatter, the git hooks, mise? | `.config/<concern>/` | `markdown/markdownlint.jsonc`, `mise/config.toml` (`lefthook.yml` top-level) |
| 3 | Does it provision the container or its services? | `.devcontainer/` | `image/Dockerfile`, `devcontainer.json`, `env.schema.yaml`, `stacks/` |
| 4 | Does it declare the repository, or enforce the scaffold's own structure? | `.repo/` | `repository.toml`, the `repo` CLI and its policies |

Why `.config/` is dotted: it is repo infrastructure, and it sits alongside the
other infrastructure directories this repo already has — `.devcontainer/`,
`.github/`, `.repo/`. Undotted at the root are the product directory and the
entry points people open first; dotted is the machinery that operates on the
repository (see [LAYOUT.md](LAYOUT.md#the-rule)).

Three rules make the `.config/` home hold:

- **Bucket by concern.** `.config/<concern>/<tool>.<ext>` — a one-file bucket
  is fine and collects siblings over time. The single exception is
  `lefthook.yml`, which sits at the top level because lefthook's config search
  does not descend past `.config/lefthook.*`. (`mise/` is a bucket because
  mise looks there.)
- **Pass the config path explicitly.** Every caller names its config with the
  tool's own flag (`--config`, `-c`, `-config-file`). The exceptions are
  lefthook and mise, which search `.config/` natively. Relying on default discovery is
  what scatters dotfiles across the root to begin with.
- **Every config must have a caller.** A file nothing reads is dead weight.
  `conventions check` fails on orphans (`CONF-04`).

See [`.config/README.md`](.config/README.md) for the per-file index. The `CONF` family of
[engineering-conventions](https://github.com/musher-dev/engineering-conventions) enforces these rules; see
[`.repo/README.md`](.repo/README.md) for what this scaffold checks on its own.

## Quick Reference

| Category | Need | Canonical Location |
| --- | --- | --- |
| **Runtimes & Tools** | Anything with a usable Feature (Node, Python, Go, Java, Deno, gh, ShellCheck, psql) | `devcontainer.json` → `features` (pinned) |
| | mise itself | `.devcontainer/image/Dockerfile` → `ARG MISE_VERSION` (= `min_version`) |
| | Every other CLI (bun, uv, Task, Codex, Lefthook, linters) | `.config/mise/config.toml` + `mise.lock` |
| | Self-updating CLIs (Claude Code) | `image/scripts/lib/base-setup.sh` |
| **Tooling** | Git hooks | `.config/lefthook.yml` |
| | Markdown lint rules | `.config/markdown/markdownlint.jsonc` |
| | YAML lint rules | `.config/yaml/yamllint.yaml` |
| | GitHub Actions lint rules | `.config/actions/actionlint.yaml` |
| | Spelling dictionary / ignores | `.config/spelling/codespell.cfg` |
| | Dockerfile lint rules | `.config/docker/hadolint.yaml` |
| | Commit types and scopes | `.config/commits/committed.toml` |
| | Task automation for the template | `Taskfile.yml` + `taskfiles/<name>.Taskfile.yml` |
| | General repository rules | engineering-conventions, pinned in `.config/mise/config.toml` |
| | The scaffold's own policies | `.repo/governance/policies/` |
| **Editor** | VS Code settings (formatters, rulers, whitespace) | `devcontainer.json` → `customizations.vscode.settings` |
| | VS Code extensions | `devcontainer.json` → `customizations.vscode.extensions` |
| | Debug launch configs | `.vscode/launch.json` (in consuming project) |
| **Shell & User** | Default shell, prompt, oh-my-zsh config | `devcontainer.json` → `common-utils` feature |
| | Git config | Host `.gitconfig` (auto-forwarded by devcontainers) |
| **Environment** | Runtime behavior vars (`PYTHONUNBUFFERED`, etc.) | `devcontainer.json` → `containerEnv` |
| | PATH extensions | `devcontainer.json` → `remoteEnv` |
| | Service credentials (dev-only) | `.devcontainer/env.schema.yaml` → written to `.env` by `repo env sync` |
| | Service profiles/toggles | `COMPOSE_PROFILES` (set it with `task env:setup`) |
| | Secrets (API keys, tokens) | `source: host` bindings: Codespaces secrets, or `${localEnv:...}` in `remoteEnv` |
| **Services** | Stack orchestrator (`include:` list) | `.devcontainer/stacks/compose.yaml` |
| | Infrastructure services | `.devcontainer/stacks/<name>/compose.yaml` |
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
| **Lifecycle** | One-time container setup | `image/scripts/post-create.sh` → `lib/base-setup.sh` |
| | Every-start tasks | `image/scripts/startup.sh` |
| | Task automation (consuming project) | `Taskfile.yml` in the consuming repo |
| **AI Tools** | Claude Code (native installer) | `lib/base-setup.sh` |
| | Codex CLI (pinned) | `.config/mise/config.toml` |
| | AI CLI config persistence | `image/devcontainer.json` → `mounts` (named volumes), `CLAUDE_CONFIG_DIR` |
| **Security** | Container capabilities | `devcontainer.json` → `capAdd` / `securityOpt` |
| | Docker build context | `.devcontainer/image/` (holds no `.env`) |
| | Network binding | Compose files → all ports bound to `127.0.0.1` |

---

## Runtimes & Tools

Tools land in one of three places. Ask these in order and stop at the first "yes".

| # | Question | Home |
| --- | --- | --- |
| 1 | Is there a Feature, **and** does its installer avoid `api.github.com`? | `devcontainer.json` → `features` |
| 2 | Does the tool update itself? | `scripts/lib/base-setup.sh` |
| 3 | Anything else (bun, uv, Task, Codex, Lefthook, the linters, engineering-conventions) | `.config/mise/config.toml`, locked |

The image itself bakes exactly one tool: **mise**, at `ARG MISE_VERSION` in
[`.devcontainer/image/Dockerfile`](.devcontainer/image/Dockerfile), which equals the configuration's `min_version`
(`TOOL-04`). Why only mise: [decision 0003](docs/decisions/0003-the-image-bakes-only-mise.md).

### 1. Tools with a Feature → `devcontainer.json`

Runtimes and any CLI that ships a devcontainer Feature are pinned in the `features` block, so they're baked into the
image:

```jsonc
"features": {
  "ghcr.io/devcontainers/features/node:1": { "version": "24.18.0" },
  "ghcr.io/devcontainers/features/python:1": { "version": "3.13.14" },
  "ghcr.io/devcontainers-extra/features/deno:1": { "version": "2.9.2" }
}
```

The platform Features (common-utils, git, github-cli, docker-in-docker, shellcheck, postgresql-client) belong to the
published image, in [`.devcontainer/image/devcontainer.json`](.devcontainer/image/devcontainer.json). The runtimes
are a repository's own, in `.devcontainer/devcontainer.json`. Comment out any you don't need (and its matching VS Code
extension). Pin an exact version where the Feature supports it; a couple track a major line instead (`java: 17`,
`postgresql-client: 16`).

Before adding a third-party Feature, read its `install.sh`. If it delegates to
`ghcr.io/devcontainers-extra/features/gh-release` (directly or via nanolayer), it belongs in mise instead. Those
Features resolve release assets by calling `api.github.com` **with no credentials** —
`nanolayer/installers/gh_release/resolvers/asset_resolver.py`:

```python
response = urllib.request.urlopen(
    f"https://api.github.com/repos/{repo}/releases/tags/{tag}"
)  # nosec
```

Codespaces build hosts and GitHub-hosted Actions runners share egress IP pools, so the 60 req/hr anonymous limit is
routinely exhausted and the call 403s. One failed Feature fails the entire image build, and pinning the version does
not help: the pin only supplies the tag, and the asset listing still calls the API. That is why bun, uv and Task are
not Features.

**Features that were checked and cleared**, and stay Features: `devcontainers-extra/deno` and `lukewiwa/shellcheck`
build a `releases/download/...` URL directly; `robbert229/postgresql-client` is apt. The rule is about the
installer's behaviour, not the publisher.

### 2. Self-updating CLIs → `scripts/lib/base-setup.sh`

CLIs that manage their own updates (Claude Code) install via their native installer. Add a function and call it from
`base_setup()`:

```bash
base_install_mytool() {
  has_cmd mytool && return 0
  log "Installing mytool..."
  retry 3 5 bash -c 'curl -fsSL https://mytool.dev/install.sh | bash'
}
```

### 3. Everything else → `.config/mise/config.toml`

[mise](https://mise.jdx.dev) pins every other CLI, in the repository's one mise configuration (`TOOL-01`). Add a line
under `[tools]`, with a fully qualified backend, then lock it:

```toml
[tools]
"aqua:go-task/task" = "3.52.0"
"npm:@openai/codex" = "0.143.0"
```

```bash
mise lock --platform linux-x64,linux-arm64,macos-arm64   # commit .config/mise/mise.lock beside it (TOOL-05)
task tools:install                                       # mise install --locked
```

`mise.lock` records each download URL and checksum, so `mise install --locked` makes none of the API calls that
rate-limit the Features above. post-create runs it against the workspace, and CI resolves the same pins through
`jdx/mise-action`.

Constraints on the Dockerfile:

- **Features layer *after* the Dockerfile**, so it cannot use anything a Feature provides, and mise pins arrive only
  at post-create. Nothing that runs before post-create may need bun, uv or Task.
- **Runtime identity is not the Dockerfile's job.** There is no `USER` instruction; `updateRemoteUserUID` expects
  root at build time and `remoteUser` owns identity afterwards. Anything touching the named-volume mount points
  (`~/.claude`, `~/.config/gh`, `~/.codex`) belongs in post-create.
- **Version assertions are presence-only** (`test -x`): executing a binary in the layer that installed it is a known
  BuildKit hazard. `scripts/verify-toolchain.sh`, run by CI against the built container, asserts mise reports its
  pin and `mise ls --missing` is empty.

The build context is `.devcontainer/image/`, which holds only the Dockerfile, its `devcontainer.json` and the
`scripts/` the Dockerfile copies to `/usr/local/share/musher-devcontainer/`. `.devcontainer/.env` is outside it, so it
never reaches the Docker daemon.

---

## Comments

This template is read before it is run, so its comments are part of the interface. Four rules, the first two
enforced by `repo comments check`.

**Comment the non-obvious.** The code states *what*; a comment earns its line by stating *why*. The test: could
someone who has never seen this code write the comment just by reading the line below it? If so, delete it.

**Write each rationale once, then reference it.** A decision explained at every call site is a decision that will
disagree with itself within a release. The full account lives here in `CONFIGURATION.md`; code carries a one-line
summary and a pointer. `repo comments check` (`CMT-03`) fails the build if a pointer stops resolving, so
references are safe to rely on.

**Keep file headers short.** A header says what the file is and the one constraint a reader must not violate.
Depth goes here. Blocks over 20 lines fail `CMT-01` — the natural size in this repo is 4–8.

**Library functions are the exception.** Every function in `.devcontainer/image/scripts/lib/` carries a full header, per
the [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html): *"Any function in a library
must have a function header comment regardless of length or complexity."* Tags go in Google's order — `Globals`,
`Arguments`, `Outputs`, `Returns` — and annotate access mode (`— read`, `— modified (export)`).

```bash
# Polls compose services until all report healthy or timeout elapses.
#
# Globals:
#   COMPOSE_FILE — read, path to stacks/compose.yaml
# Arguments:
#   $1 — timeout in seconds (default: 60)
# Outputs:
#   Writes progress/warnings to stderr via log()
# Returns:
#   0 when healthy or on timeout (non-fatal), 1 if services failed
```

---

## Editor

### VS Code Settings

All editor settings live in `devcontainer.json` → `customizations.vscode.settings`. Do not create a
`.vscode/settings.json` in the template — that's for consuming projects.

### VS Code Extensions

All extensions live in `devcontainer.json` → `customizations.vscode.extensions`. Comment out extensions for runtimes you
don't use.

### Why there is no `.editorconfig`

Editor intent is expressed once, in `devcontainer.json` →
`customizations.vscode.settings` (LF endings, final newline, trimmed trailing
whitespace, rulers at 80/120). Adding `.editorconfig` would create a second
place to state the same thing, and the two would drift.

The tradeoff is deliberate and worth knowing: those settings only reach VS Code
*inside the container*. Another editor, or a host-side edit, is not covered. Two
things backstop that gap — `.gitattributes` enforces line endings for every
file Git checks out regardless of editor, and the lint gates (`task lint:all`,
and the same checks in CI) fail on violations no matter what wrote the file.

If a consuming project has contributors who work outside the container, adding
`.editorconfig` there is the right call. It does not belong in the template.

---

## Shell & User

### Git Config

Git config is auto-forwarded from your host machine by the devcontainer CLI. No configuration needed in the template.

---

## Environment Variables

There are four distinct scopes for environment variables. Use the right one:

| Scope | Location | When to Use |
| --- | --- | --- |
| **Container-wide** | `devcontainer.json` → `containerEnv` | Runtime behavior (`PYTHONUNBUFFERED`, `UV_LINK_MODE`) |
| **Remote/IDE** | `devcontainer.json` → `remoteEnv` | PATH extensions, forwarded host secrets |
| **Compose services and shells** | `.devcontainer/.env` | Service credentials, `COMPOSE_PROFILES` |
| **Service-specific** | `stacks/<name>/compose.yaml` → `environment:` | Internal service config (uses `${VAR:-default}` interpolation) |

### Secrets

Never commit secrets. Declare the binding with `source: host`, list it in `devcontainer.json` → `secrets` so
Codespaces prompts for it (`ENVS-15`), and forward it from your host environment when you build locally:

```jsonc
"remoteEnv": {
  "MY_API_KEY": "${localEnv:MY_API_KEY}"
}
```

`repo env sync` copies the value into an empty binding in `.env`; a value you set there is never overwritten.

### The schema is the source of truth

Every variable the dev environment reads is declared in
[`.devcontainer/env.schema.yaml`](.devcontainer/env.schema.yaml). No environment file is committed (`ENVS-26`):
post-create runs `repo env sync`, which writes `.devcontainer/.env` from the schema on first create and afterwards only
adds what the schema has gained. Why it is generated in the container:
[decision 0002](docs/decisions/0002-the-dev-env-file-is-generated-in-the-container.md). The schema's shape is
engineering-conventions' (`ENVS-03`); `repo env check` keeps it in step with the compose stacks.

The product's own runtime contract is a *different* schema, at `<product>/env.schema.yaml` — see
[LAYOUT.md](LAYOUT.md#the-env-contract) for why they sit at different levels.

```yaml
bindings:
  MINIO_ROOT_PASSWORD:
    type: string
    local_default: minioadmin     # → `MINIO_ROOT_PASSWORD=minioadmin`
    sensitivity: internal         # public | internal | confidential | secret
    consumers: [minio]            # only required when the minio stack runs
    description: Root password of the project MinIO stack. Dev-only.
```

| Field | Effect |
| --- | --- |
| `local_default` | Written live: `VAR=value`. A `secret` may only carry an empty or loopback value (`ENVS-06`). |
| `required: true` | Written empty: `VAR=`. `repo env doctor` asks for it. |
| neither | Written commented: `# VAR=<default>` — an offer, not a value. |
| `consumers: [<stack>]` | Requiredness follows the enabled `COMPOSE_PROFILES`. Checked against the stack's compose file (`ENV-03`). |
| `source: host` | Taken from the environment (a Codespaces secret, or `${localEnv:...}`) by `repo env sync`, and mirrored into `secrets` so Codespaces prompts (`ENVS-15`). |
| `local_generate: hex:32` | Minted per developer by `repo env sync` (`hex`, `base64` or `base64url`, in bytes), never committed. |
| `mirrored_in: [...]` | Configs that repeat the value literally (Tempo, Loki) must agree (`ENV-05`). |

### Filling it in

The container always starts. What does not start is the stack whose value is missing:

| Command | Purpose |
| --- | --- |
| `task env:setup` | Interactive fill — asks only for what is missing or invalid, masks secrets, offers menus |
| `task env:doctor` | What the *enabled* stacks still need, and which ones will be skipped |
| `task env:sync` | Writes `.env`, or adds bindings the schema has gained; mints local secrets; never overwrites a value |
| `task env:reset` | Rewrites `.env` from the schema (destroys local values) |

`startup.sh` skips a stack whose required values are missing and says so; the MOTD repeats it on every shell. The
shell profile loads the file (`lib/env-load.sh`), so an edited value reaches new terminals without a rebuild. `.env`
values reach shells and what they start, not every process in the container: an editor's extension host does not
see them.

---

## Services

### Enabling/Disabling Services

All services are included in `.devcontainer/stacks/compose.yaml`. Optional services are gated by Compose profiles:

| Service | Profile | Always On? |
| --- | --- | --- |
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
2. Add `- myservice/compose.yaml` to the `include:` list in `stacks/compose.yaml`
   (paths are relative to that file)
3. Optionally add `profiles: [myservice]` if it should be opt-in
4. Add port forwarding in `devcontainer.json` → `forwardPorts` and `portsAttributes`
5. Use `${VAR:-default}` for any credentials, and declare them in `.devcontainer/env.schema.yaml` with
   `consumers: [myservice]`

### Service Configuration

Each stack owns its config: put a stack's config files inside its own folder,
next to that stack's `compose.yaml`, and bind-mount them with a path relative to
the stack folder (e.g. `./init`, `./config/...`):

```text
stacks/
  compose.yaml          The orchestrator: `include:` one line per stack
  postgres/
    compose.yaml
    init/               SQL init scripts (mounted at ./init)
  observability/
    compose.yaml
    config/             OTel, Grafana, Tempo, Loki configs (mounted at ./config)
```

Relative paths inside a stack's `compose.yaml` resolve against *that file's* folder, not the orchestrator's, so a
stack stays self-contained.

### Why every caller passes `--env-file`

Compose discovers `.env` in the project directory, which defaults to the folder holding the first `-f` file. The
orchestrator lives in `stacks/` and `.env` lives in `.devcontainer/`, so that discovery does not reach it. Every
caller — `scripts/startup.sh`, the MOTD, and CI — therefore names it explicitly:

```bash
docker compose --env-file .devcontainer/.env -f .devcontainer/stacks/compose.yaml up -d
```

Omitting it does not error. Every `${VAR:-default}` quietly takes its default and `COMPOSE_PROFILES` reads as empty,
so all opt-in stacks silently vanish. The orchestrator also sets `name: musher-dev` explicitly, because Compose
would otherwise derive the project name from the `stacks/` folder.

---

## Networking

### Port Allocation

All ports are bound to `127.0.0.1` (localhost only) for security. The template uses the `154xx` range:

| Port | Service | Protocol |
| --- | --- | --- |
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

Services communicate via the `musher-dev` Docker network. Use the service name as the hostname (e.g., `postgres`,
`redis`, `minio-observability`) with the container-internal port.

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
| --- | --- |
| `stacks/observability/config/otel-collector-config.yaml` | OTel Collector pipeline configuration |
| `stacks/observability/config/tempo-config.yaml` | Tempo storage and ingestion config |
| `stacks/observability/config/loki-config.yaml` | Loki storage and ingestion config |
| `stacks/observability/config/grafana/provisioning/datasources/` | Auto-provisioned Grafana datasources |
| `stacks/observability/config/grafana/provisioning/dashboards/json/` | Auto-provisioned Grafana dashboards |

> **Note:** `tempo-config.yaml` and `loki-config.yaml` contain hardcoded MinIO credentials because they are native YAML
configs that don't support environment variable interpolation. If you change `MINIO_OBS_ROOT_USER` or
`MINIO_OBS_ROOT_PASSWORD` in `.env`, you must also update these files to match.

---

## Data

### Database Initialization

SQL files in `.devcontainer/stacks/postgres/init/` are mounted into PostgreSQL's `docker-entrypoint-initdb.d/` and run
in alphabetical order on first container creation:

- `00-init.sql` — Base schema (extensions, shared types)
- `01-project.sql.example` — Project-specific schema (copy to `01-project.sql`)

### Persistence

All services use named Docker volumes (e.g., `musher-postgres-data`). Data persists across container restarts but is
lost on full rebuild. For migrations, use project-level tooling (Atlas, Flyway, etc.).

### Adding Volumes

Follow the naming convention `musher-${devcontainerId}-<purpose>`:

```jsonc
"source=musher-${devcontainerId}-my-tool,target=/home/vscode/.my-tool,type=volume"
```

---

## Lifecycle

| Hook | Runs | Use For |
| --- | --- | --- |
| `postCreateCommand` | Once, on container creation | Tool installation, permissions, lefthook hooks, writing `.env` |
| `postStartCommand` | Every container start | `docker compose up`, health checks |

There is no `initializeCommand`: nothing runs on the host. The image's metadata carries its own lifecycle commands,
which run the scripts baked at `/usr/local/share/musher-devcontainer/`; a repository's own `postCreateCommand` runs
after them. The scripts find the workspace with `workspace_root` (the lifecycle command's working directory, or
`MUSHER_WORKSPACE`), never from their own path, so the same code runs baked and from `.devcontainer/image/scripts/`.

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

```text
post-create.sh              ← Entry point (repo-specific customization)
  └── lib/base-setup.sh     ← Reusable orchestrator (mise CLIs, Claude, nvm, config/cache dirs)
        └── lib/common.sh   ← Shared utilities (log, retry, has_cmd, ensure_writable_dir)
```

---

## AI Tools

### Installed CLIs

- **Claude Code** — native self-updating installer (`base-setup.sh`), config persisted in the `~/.claude` volume
- **Codex CLI** — pinned in `.config/mise/config.toml`, config persisted in the `~/.codex` volume

### Configuration Persistence

AI CLI configs are stored in named volumes, one per tool per container (`musher-${devcontainerId}-<tool>-config`, the
only form `DEVC-08` accepts), mounted via the image's `devcontainer.json` → `mounts`. This preserves authentication and
settings across container rebuilds. `CLAUDE_CONFIG_DIR` points Claude Code at its volume, so `.claude.json` survives a
rebuild too.

---

## Directory Map

```text
<product>/                    The product (absent in the template; see LAYOUT.md)
AGENTS.md                     Agent-facing contract (imports README.md; there is no CLAUDE.md)
LAYOUT.md                     Which level a file belongs to: repository or product
CHANGELOG.md  version.txt     Written by release-please
docs/decisions/               Why the scaffold is shaped the way it is
.config/                      Tool configuration (see "Where configuration lives")
  README.md                   Index: every file, its tool, and how it is reached
  lefthook.yml                Git hooks (top-level: lefthook's search stops at .config/lefthook.*)
  lefthook-local.yml          Personal hook overrides (gitignored, auto-merged)
  mise/config.toml            Every CLI pin but mise itself (+ mise.lock)
  markdown/markdownlint.jsonc Markdown rules      (--config)
  yaml/yamllint.yaml          YAML rules          (--config)
  actions/actionlint.yaml     Workflow rules      (-config-file)
  spelling/codespell.cfg      Spelling            (--config)
  docker/hadolint.yaml        Dockerfile rules    (--config)
  commits/committed.toml      Commit types/scopes (--config)
.repo/                        Declarations, and the scaffold's own `repo` CLI
  README.md                   What each policy enforces, and why
  repository.toml             Identity and [layout] (`product = ""` here)
  conventions.toml            Waivers for engineering-conventions
  outputs.toml                The published image (OUT-01)
  pyproject.toml              uv project; declares the `repo` console-script
  tests/                      pytest suite for the policies and env tools
  governance/
    cli.py                    `repo check` and the per-policy subcommands
    reporting.py              The Violation record (code, reason, fix)
    repo.py                   Repo-root discovery, YAML/JSONC/TOML readers, tracked files
    globs.py                  Glob matching shared by the path policies
    dotenv.py  envtools.py    `repo env sync|doctor|setup`
    policies/__init__.py      The policy registry -- the only wiring a policy needs
    policies/layout/          Dev container mounts and editor links vs the declared product
    policies/paths/           .gitattributes, paths-filter and .claude/rules globs still match
    policies/env/             The env schema and the compose stacks agree
    policies/ports/           Port table ↔ forwardPorts ↔ compose parity
    policies/hooks/           lefthook ↔ CI job parity
    policies/comments/        Comment-block size and live docs pointers
.github/
  CODEOWNERS                  Every path: @musher-dev/engineering
  dependabot.yml              Weekly updates: devcontainers, actions, docker
  release-please/             Release configuration and manifest
  rulesets/                   Branch and tag protection as committed JSON (infra-github applies them)
  workflows/                  Validate, Validate Pull Request, Release
taskfiles/                    Task modules included by the root Taskfile.yml
Taskfile.yml                  Task entry point (cannot move — root-only discovery)
.gitattributes                Line-ending policy (`* text=auto eol=lf`)
.devcontainer/
  devcontainer.json           This repository's container: builds image/, adds runtimes, ports
  devcontainer-lock.json      Feature digests (--frozen-lockfile in CI)
  env.schema.yaml             Dev-environment contract -- the source of truth
  .env                        Written by `repo env sync` (gitignored)
  image/                      The published image (decision 0001)
    devcontainer.json         Platform Features, user, mounts, env, lifecycle -> metadata label
    devcontainer-lock.json    Its Feature digests
    Dockerfile                Bakes mise; copies scripts/ to /usr/local/share/musher-devcontainer/
    scripts/
      post-create.sh          One-time setup entry point
      startup.sh              Every-start service launcher
      verify-toolchain.sh     Asserts mise and every mise pin (CI)
      lib/
        base-setup.sh         Reusable tool installer (mise pins, Claude, the repo CLI)
        common.sh             Shared utilities
        env-load.sh           Exports .env into a shell without sourcing it
        motd.sh               Startup MOTD renderer
        version.sh            The release these scripts belong to (release-please)
  stacks/                     The services, and the orchestrator that includes them
    compose.yaml              Stack orchestrator (`include:` + `name: musher-dev`)
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
```
