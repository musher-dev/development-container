# `.config/` — Tool Configuration

Every linter, formatter, and hook config lives here. One directory, one purpose:
if a tool needs a config file and it is not provisioning the container, it goes
in here.

Policy and rationale: [`CONFIGURATION.md`](../CONFIGURATION.md). Enforcement:
`repo config check` (see [`.repo/`](../.repo/README.md)).

## Index

| File | Tool | How it is reached |
| --- | --- | --- |
| `lefthook.yml` | lefthook | **Auto-discovered.** Lefthook searches `.config/lefthook.*` natively |
| `lefthook-local.yml` | lefthook | Auto-discovered and merged. Gitignored; personal overrides only |
| `markdownlint.jsonc` | markdownlint-cli2 | `--config .config/markdownlint.jsonc` |
| `yamllint.yaml` | yamllint | `-c .config/yamllint.yaml` |
| `actionlint.yaml` | actionlint | `-config-file .config/actionlint.yaml` |
| `codespell.cfg` | codespell | `--config .config/codespell.cfg` |

Call sites are [`taskfiles/lint.Taskfile.yml`](../taskfiles/lint.Taskfile.yml)
and [`.github/workflows/validate.yaml`](../.github/workflows/validate.yaml).
Tool versions are pinned in one place —
[`.devcontainer/mise.toml`](../.devcontainer/mise.toml) — and CI resolves them
from that same file via `jdx/mise-action`.

## Rules

1. **Flat.** `.config/<tool>.<ext>`. Create a `.config/<tool>/` subdirectory
   only when a tool genuinely owns several files (a style directory, a custom
   dictionary set). One file per tool needs no folder.
2. **No leading dot on filenames.** The directory is already dotted; a second
   dot adds nothing.
3. **Pass the path explicitly.** Except for lefthook, which finds this
   directory on its own, every caller names its config with the tool's config
   flag. Never rely on default discovery — that is what put these files at the
   repo root in the first place.
4. **Every file must have a caller.** A config nothing reads is dead weight;
   `repo config check` fails on orphans and on files missing from the table
   above.
5. **Every ignore needs a reason.** Suppressions, allowlists, and disabled
   rules carry an inline comment explaining why the exception is acceptable.

## What does *not* live here

| Thing | Where | Why |
| --- | --- | --- |
| `Taskfile.yml` | Repo root | Task only discovers `Taskfile.*` at the root; `--taskfile` would break bare `task <name>` |
| `mise.toml` | `.devcontainer/` | It provisions the container, rather than checking the code |
| `compose.yaml`, stack configs | `.devcontainer/` | Same — environment, not code quality |
| `.gitattributes`, `.gitignore` | Repo root | Git reads these from the root only |
| VS Code settings | `devcontainer.json` | `customizations.vscode.settings` is the single editor source |

## A trap worth knowing

Lefthook's config search is **first-match-wins**, in this order:

```text
lefthook.*  →  .lefthook.*  →  .config/lefthook.*
```

A stray `lefthook.yml` at the repo root therefore **silently shadows** this
directory's copy — no warning, no error, just different hooks. `repo config
check` fails the build if one appears.
