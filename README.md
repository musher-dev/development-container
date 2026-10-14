# Musher Dev Container Template

Canonical dev container for the musher-dev organization: the template a new repository starts from. It builds on the
Microsoft base image (`mcr.microsoft.com/devcontainers/base:ubuntu-24.04`) with pinned Features and lifecycle scripts
of its own; there is no image to publish or pin. Batteries-included: AI CLIs, multiple language runtimes,
Docker-in-Docker, Task, and consistent VS Code settings. Comment out what you don't need.

## What You Get

- Ubuntu 24.04 LTS base with zsh/oh-my-zsh
- Node, Python, Go, Java, Deno — pinned Features; pnpm and yarn through corepack, from `package.json`'s
  `packageManager`
- mise, from a local Feature ([`.devcontainer/features/mise/`](.devcontainer/features/mise/)); every other CLI (bun,
  uv, Task, Codex, Lefthook, the linters, engineering-conventions) a locked pin in
  [`.config/mise/config.toml`](.config/mise/config.toml)
- Opt-in, commented out until you need them: Rust (a Feature), OpenTofu, tflint, terraform-docs, doctl, cloudflared
  and buf (mise pins)
- Docker-in-Docker, Git + GitHub CLI, Claude Code
- GitLens, YAML, TOML, Copilot, Go, Python, Ruff, ESLint, Docker extensions
- Format on save, rulers, trailing whitespace trimming

## Start a New Repository

1. Click **Use this template** → **Create a new repository** on GitHub.
2. Delete `docs/decisions/` — those records are about this scaffold, not your repository.
3. Set your identity in `.repo/repository.toml` (`name`, `system`, `component`, `kind`, `owner`).
4. Clone it, open it in VS Code, and run **Dev Containers: Reopen in Container**.
5. *(Optional)* Run `task env:setup` to choose which stacks start and fill in any values they need.

The general rules — layout, configuration, workflows, toolchain — are
[engineering-conventions](https://github.com/musher-dev/engineering-conventions), pinned in
`.config/mise/config.toml` and run by `task conventions`. `.repo/` holds only the scaffold's own checks and the env
tools post-create uses (`repo env sync`); keep it, since post-create installs the `repo` CLI from it.

## Local Environment

Every variable the dev environment reads is declared in `.devcontainer/env.schema.yaml`. No environment file is
committed (ENVS-26): post-create runs `repo env sync`, which writes `.devcontainer/.env` (gitignored) from the
schema on first create, and later only adds what the schema has gained. The file feeds:

- **Docker Compose** — passed explicitly as `--env-file .devcontainer/.env` by every caller, used to interpolate
  `${VAR:-default}` references. It is not auto-discovered: the orchestrator lives at
  `.devcontainer/stacks/compose.yaml` and `.env` is not its sibling.
- **Your shells** — the shell profile loads `.env`, so every new terminal and every task run from it sees the current
  values, edits included, without a rebuild.

A binding the schema marks `source: host` takes its value from the environment: a Codespaces secret, or a host
variable you pass through `remoteEnv` as `"${localEnv:NAME}"`. A missing value never blocks the container — it blocks
the stack that needs it, and only while that stack's profile is enabled. Useful task commands:

| Command | Purpose |
| --- | --- |
| `task setup` | Install the pinned CLIs, the git hooks and `.env` (post-create runs the same). |
| `task env:setup` | Fill in what is missing, interactively (menus for stack choices, masked secrets). |
| `task env:doctor` | Report what the enabled stacks still need, and which ones will be skipped. |
| `task env:sync` | Write `.env`, or add bindings the schema has gained; never overwrites a value you set. |
| `task env:reset` | Rewrite `.env` from the schema (prompts before overwriting). |
| `task stacks:restart` | Bring the stacks up to match the current `.env`. |
| `task lint` | Run every lint gate (Markdown, YAML, workflows, spelling). |
| `task check` | Run every gate CI runs that can run locally, engineering-conventions included. |
| `task tools:install` | Install every pinned CLI from `.config/mise/config.toml`. |

The startup MOTD repeats anything still outstanding.

## Customize

- Add your product → a directory named after the repo, declared in `.repo/repository.toml` under `[layout]`. The
  repository root stays the machinery that acts on it; [docs/layout.md](docs/layout.md) is the rule.
- Comment out unneeded features/extensions in `devcontainer.json`.
- Change a tool version → `devcontainer.json` (Features) or `.config/mise/config.toml` (everything else; run
  `mise lock` after). The tier rule is in [docs/configuration.md](docs/configuration.md#runtimes--tools).
- Change a lint rule → the matching file in `.config/` (see [`.config/README.md`](.config/README.md)).
- Add project setup → `main` in [`.devcontainer/scripts/post-create.sh`](.devcontainer/scripts/post-create.sh), below
  the marked line.
- Add a runtime → uncomment Rust in `devcontainer.json`, or an optional pin in `.config/mise/config.toml` (then
  `mise lock`).
- Add or enable a service → `.devcontainer/stacks/` (one folder per stack, registered in `stacks/compose.yaml`);
  toggle with `COMPOSE_PROFILES` in `.devcontainer/.env` (redis, minio, registry, azimutt, observability).
- Full reference → [docs/configuration.md](docs/configuration.md).

## Included CI

`.github/workflows/validate.yaml` runs ShellCheck, Compose config validation, the lint gates,
engineering-conventions, the scaffold's own policies and their tests, the dev container configuration against its
lockfile, and a full container build that asserts every pinned tool installed. Its
`Validate / Required` job is the one context the branch ruleset requires; `validate-pull-request.yaml` adds the
pull request title check. Tool versions resolve from `.config/mise/config.toml` — the same file the container uses.

The same lint and structure checks run pre-commit via [`.config/lefthook.yml`](.config/lefthook.yml), and
`repo hooks check` fails the build if the two ever disagree.

Branch protection is committed under [`.github/rulesets/`](.github/rulesets/); musher-dev/infra-github applies it.
Nothing is released: a repository takes the template once and owns its copy from then on.

## Troubleshooting

### CRLF / WSL line ending issues

`.gitattributes` (`* text=auto eol=lf`) normalizes every tracked file, so scripts arrive with LF on every platform.
`.devcontainer/.env` is gitignored and out of its reach; the shell loader strips a stray `\r` from it.

### Stale containers

If settings aren't applying after changes, rebuild without cache:

**Command Palette** → **Dev Containers: Rebuild Container Without Cache**

### Volume permission errors

Named volumes may initialize with root ownership. The `ensure_writable_dir` function in `common.sh` and the
`base_setup_config_dirs` step handle this for base volumes; they recurse only when a directory's own owner is wrong.

### Running out of disk

Docker-in-Docker keeps its images and build cache on a volume that survives rebuilds, so it only grows. `task
docker:prune` removes the build cache, stopped containers and unused images, and keeps every volume (stack data
included). Under Docker Desktop on Windows, the freed space can stay allocated in WSL's virtual disk until that
`.vhdx` is compacted (`wsl --shutdown`, then `Optimize-VHD` or `diskpart`'s `compact vdisk`).

### Tool installation failures

Base setup uses `retry` with 3 attempts and 5-second delays for network operations. If a tool consistently fails to
install, check network connectivity and try rebuilding the container.
