# `.repo/` — Repository Governance

The repository's declarations, the scaffold-specific policies this repo
enforces on itself, and the `repo` CLI that runs them and manages the dev
environment's `.env`.

The `.repo/` prefix mirrors `.github/` and `.devcontainer/`: infrastructure that
operates on the repository rather than being part of its content. It is
deliberately not `tools/` (junk-drawer risk) or `scripts/` (names the
implementation, not the purpose).

## Why this exists

This repository is a template. Whatever layout it ships is replicated into every
repo scaffolded from it, so a convention that holds only while someone remembers
it will not hold. The policies here turn the layout rules into something that
fails a build instead of a code review.

The general rules -- layout, `.config/`, workflows, rulesets, the toolchain, the
env schema's shape -- moved to
[engineering-conventions](https://github.com/musher-dev/engineering-conventions),
which this repository pins in `.config/mise/config.toml` and runs with
`conventions check` ([decision 0001](../docs/decisions/0001-the-scaffold-is-published-as-a-pinned-image.md)).
What stays here is specific to this scaffold. A new repository pins that
release; it does not copy this directory.

That choice has a cost worth stating: a checker enforces *what*, not *why*. So
every violation this CLI reports carries its own rationale and the action that
resolves it — the `reason` and `fix` fields are not decoration, they are the
documentation. The prose version lives in
[`CONFIGURATION.md`](../CONFIGURATION.md).

## Use

```bash
task repo:check            # every policy (this is what CI and pre-commit run)
task repo:check:ports      # one policy
repo check                 # same thing, without Task
repo ports check
```

The CLI is installed by the devcontainer bootstrap
(`base_install_repo_cli` in `.devcontainer/image/scripts/lib/base-setup.sh`,
which runs `uv tool install ./.repo`; a repository without `.repo/` gets it
from the release its image came from). To reinstall after editing it:
`task repo:install` — it passes `--reinstall`, because uv otherwise reuses the
cached build of an unchanged version and your edit never takes effect.

## Policies

| Policy | Codes | Enforces |
| --- | --- | --- |
| `layout` | `LAYOUT-07` | Dev container workspace mounts sit under the declared product, and the editor links name it ([LAYOUT.md](../LAYOUT.md#invariants)) |
| `paths` | `PATH-01`, `PATH-04` | Every `.gitattributes` pattern, paths-filter and `.claude/rules` `paths:` glob still matches a file, and the allowlist stays honest |
| `env` | `ENV-03`..`ENV-05` | The dev-environment schema and the compose stacks agree: every `${VAR}` is declared, every consumer is a stack that reads it, every mirrored value matches |
| `ports` | `PORT-01`..`PORT-05` | The port table, `forwardPorts`/`portsAttributes`, and compose published ports all agree, and forwarded ports stay in the reserved range |
| `hooks` | `HOOK-01`..`HOOK-04` | Every lefthook job has a CI counterpart and vice versa, or a recorded reason why not |
| `comments` | `CMT-01`..`CMT-03` | Comment blocks stay short, the allowlist stays honest, and every `docs:` pointer still resolves |

### What engineering-conventions took over

| Retired here | engineering-conventions |
| --- | --- |
| `LAYOUT-01`..`06`, `08`, `09` | `REPO-14`..`21` |
| `LAYOUT-10`, `LAYOUT-11` | `ENVS-01`, `ENVS-02` |
| `PATH-01` (lefthook globs), `PATH-02`, `PATH-03` | `HOOKS-11`, `GHA-45` + `REPO-22`, `TASK-08` |
| `CFG-01`..`CFG-09` | `CONF-01`..`CONF-09` |
| `ENV-01`, `ENV-06`, `ENV-07` | `ENVS-03`, `ENVS-15`, `ENVS-06` |
| `ENV-02` (`.env.example` freshness) | Retired with the file: no environment file is committed (`ENVS-26`) |
| `RS-01`..`RS-04` | `BRANCH-01`..`04`, `GHA-14`..`16` |
| `TC-01`..`TC-03` | `TOOL-01`, `TOOL-04`, `TOOL-05`, `TOOL-06`, `TOOL-10` |
| `PORT-05` (compose half) | `DEVC-13` |

### The one-way-check tables

`hooks` is the policy most likely to be argued with, so its exceptions are
explicit. `LOCAL_ONLY` and `CI_ONLY` in
[`policies/hooks/check.py`](governance/policies/hooks/check.py) list
every check that deliberately runs in only one place, each with a reason —
`build` is minutes long, `compose` needs a Docker daemon, `block-devcontainer-env`
has nothing to assert in CI, and `committed` is mirrored by the pull request
title check. Adding a job on either side without registering it
fails `HOOK-01`/`HOOK-03`, and an entry that outlives what it excused fails
`HOOK-04`. The allowlist cannot quietly widen.

## Layout

```text
.repo/
  pyproject.toml                 uv project; declares the `repo` console-script
  repository.toml                Identity and [layout] (REPO-01, REPO-14) -- this repo's data
  conventions.toml               Waivers for engineering-conventions -- this repo's data
  outputs.toml                   What this repo publishes (OUT-01) -- this repo's data
  tests/                         pytest suite; fixtures are built in tmp_path
  governance/
    cli.py                       Argument parsing and exit codes
    reporting.py                 The Violation record and its rendering
    repo.py                      Repo-root discovery, YAML/JSONC/TOML readers, tracked files
    globs.py                     Glob matching shared by the path policies
    dotenv.py                    Reading and writing .devcontainer/.env
    envtools.py                  `repo env doctor|sync|setup`
    policies/
      __init__.py                The policy registry
      <name>/
        violations.py            What can go wrong, and why the rule exists
        check.py                 Whether it has gone wrong
```

Each policy splits declaration from detection on purpose: `violations.py` is
where the reasoning lives and is the file to read first when a check fires.
The shared `Violation` and `Report` primitives are in `reporting.py` -- named
so that it is never confused with a policy's own `violations.py`.

There is no `src/` directory. Its purpose is to stop Python from importing a
local source tree in place of the installed package, which only happens when
the package sits in the working directory -- and this one sits under `.repo/`,
which is never where anyone works. `.repo/` already provides the separation,
so `src/` would only add a level to every path.

The three `.toml` declarations belong to the repository rather than the
template: `governance/` is code, the declarations are what this repository says
about itself. Keeping them apart is what lets the code update without merge
conflicts.

## Tests

`LAYOUT-07`'s editor-link half only fires once a product is declared, which the
template never does, so `repo check` passing here proves little about it. The suite
builds a throwaway git repository per case and asserts each code fires:

```bash
task repo:test             # uv run --project .repo --group dev pytest .repo/tests
```

## Adding a policy

1. Create `policies/<name>/` with `violations.py`, `check.py`, and an
   `__init__.py` re-exporting `run`.
2. `run()` returns a `Report`; give every violation a stable code, a `reason`,
   and a `fix`.
3. Register it in `POLICIES` in `policies/__init__.py` — it joins `repo check`
   and gains a `repo <name> check` subcommand automatically. That is the only
   wiring; `cli.py` never names an individual policy.
4. Add a row to the table above, and a test under `tests/` for every code.

## The `env` group

`env` is the one policy with developer commands beside its check, because the
schema it checks against the stacks is also what writes
`.devcontainer/.env` and tells a developer which values are still missing:

```bash
repo env check     # policy: compose parity (CI)
repo env sync      # local: write .env from the schema, or add what it gained;
                   #        mint local secrets; fill `source: host` bindings
repo env doctor    # local: what the enabled stacks still need
repo env setup     # local: fill it in, interactively
```

The check half is blocking and reads only tracked files. The others read and
write the developer's gitignored `.env`, so they are never part of
`repo check`. post-create runs `repo env sync` on every create; `--force`
rewrites the file from the schema. Why the file is generated in the container
rather than committed: [decision 0002](../docs/decisions/0002-the-dev-env-file-is-generated-in-the-container.md).
