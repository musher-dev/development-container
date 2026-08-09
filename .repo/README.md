# `.repo/` — Repository Governance

The structural policies this repo enforces on itself, and the `repo` CLI that
runs them.

The `.repo/` prefix mirrors `.github/` and `.devcontainer/`: infrastructure that
operates on the repository rather than being part of its content. It is
deliberately not `tools/` (junk-drawer risk) or `scripts/` (names the
implementation, not the purpose).

## Why this exists

This repository is a template. Whatever layout it ships is replicated into every
repo scaffolded from it, so a convention that holds only while someone remembers
it will not hold. The policies here turn the layout rules into something that
fails a build instead of a code review.

That choice has a cost worth stating: a checker enforces *what*, not *why*. So
every violation this CLI reports carries its own rationale and the action that
resolves it — the `reason` and `fix` fields are not decoration, they are the
documentation. The prose version lives in
[`CONFIGURATION.md`](../CONFIGURATION.md).

## Use

```bash
task repo:check            # every policy (this is what CI and pre-commit run)
task repo:check:config     # one policy
repo check                 # same thing, without Task
repo config check
```

The CLI is installed by the devcontainer bootstrap
(`base_install_repo_cli` in `.devcontainer/scripts/lib/base-setup.sh`, which
runs `uv tool install ./.repo`). To reinstall after editing it:
`task repo:install`.

## Policies

| Policy | Codes | Enforces |
| --- | --- | --- |
| `config` | `CFG-01`..`CFG-07` | Tool config lives in `.config/`, every file is indexed and has a caller, nothing at the root shadows it |
| `ports` | `PORT-01`..`PORT-05` | The port table, `forwardPorts`/`portsAttributes`, and compose published ports all agree and stay in the reserved range |
| `hooks` | `HOOK-01`..`HOOK-04` | Every lefthook job has a CI counterpart and vice versa, or a recorded reason why not |

### The one-way-check tables

`hooks` is the policy most likely to be argued with, so its exceptions are
explicit. `LOCAL_ONLY` and `CI_ONLY` in
[`policies/hooks/check.py`](src/repo_governance/policies/hooks/check.py) list
every check that deliberately runs in only one place, each with a reason —
`build` is minutes long, `compose` needs a Docker daemon, `block-devcontainer-env`
has nothing to assert in CI. Adding a job on either side without registering it
fails `HOOK-01`/`HOOK-03`, and an entry that outlives what it excused fails
`HOOK-04`. The allowlist cannot quietly widen.

## Layout

```text
.repo/
  pyproject.toml                 uv project; declares the `repo` console-script
  src/repo_governance/
    cli.py                       Argument parsing and exit codes
    repo.py                      Repo-root discovery, YAML/JSONC readers
    violations.py                The Violation record and its rendering
    policies/<name>/
      violations.py              What can go wrong, and why the rule exists
      check.py                   Whether it has gone wrong
```

Each policy splits declaration from detection on purpose: `violations.py` is
where the reasoning lives and is the file to read first when a check fires.

## Adding a policy

1. Create `policies/<name>/` with `violations.py`, `check.py`, and an
   `__init__.py` re-exporting `run`.
2. `run()` returns a `Report`; give every violation a stable code, a `reason`,
   and a `fix`.
3. Register it in `POLICIES` in `cli.py` — it joins `repo check` and gains a
   `repo <name> check` subcommand automatically.
4. Add a row to the table above.

## Not yet folded in

Env-template parity (`.env` versus `.env.example`) stays in
`.devcontainer/scripts/lib/env-check.sh`. It already has three consumers — the
`env:*` tasks, the startup MOTD, and CI — and reimplementing it here would
duplicate the logic and put the MOTD path at risk. Consolidating it is a
reasonable future change; doing it as part of introducing `.repo/` was not.
