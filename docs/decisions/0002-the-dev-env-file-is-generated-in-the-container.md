---
title: The dev environment's .env is generated inside the container, and nothing runs on the host
date: 2026-10-03
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
---

# 0002 — The dev environment's .env is generated inside the container, and nothing runs on the host

## Context

`.devcontainer/.env` used to be seeded on the host: `initializeCommand` ran `initialize.sh`, which copied a
committed `.env.example` (rendered from `env.schema.yaml`) so that `runArgs --env-file` had a target at
`docker run` time, and filled `# @host`-marked keys from the host's environment.

engineering-conventions 0.8.0 reports a committed environment file beside a schema (ENVS-26,
[decision 0029][ec-0029]), and defers its host-safety
rules until the scaffold no longer needs a host-side hook ([decision 0020][ec-0020]).

## Decision

We will generate `.devcontainer/.env` inside the container and run nothing on the host.

- `initializeCommand`, `initialize.sh`, `runArgs --env-file` and `.env.example` are removed.
- post-create runs `repo env sync`, which writes `.env` from the schema when it is missing, and otherwise only adds
  the bindings the schema has gained and mints local secrets. A `source: host` binding takes the value of the
  same name from the environment: a Codespaces secret, or a host variable passed through `remoteEnv` as
  `${localEnv:NAME}`.
- Shells load the file through `lib/env-load.sh`; every Compose call names it with `--env-file`.

## Consequences

### Positive

- One source of truth for the environment: the schema. No rendered copy to keep in step.
- Nothing executes on the developer's host.

### Negative

- `.env` values reach shells and the processes started from them, not every process in the container: a VS Code
  extension host no longer sees them.

### Neutral

- `repo env render` and ENV-02 are gone; `task env:reset` is `repo env sync --force`.

## Enforcement

- ENVS-26 fails on a committed `.env.example`.
- ENVS-15 keeps `secrets` in step with the `source: host` bindings.
- `.repo/tests/test_envtools.py` covers writing, syncing, minting and the host fill.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| A | Keep `initialize.sh`, but only touch an empty `.env` | rejected: keeps the host hook |
| B | `conventions env-file` on the host | rejected: needs mise, conftest and jq on the host |
| C | Generate in post-create; load in shells | **chosen** |

## References

- musher-dev/development-container#28, step 7

[ec-0020]: https://github.com/musher-dev/engineering-conventions/blob/v0.8.0/docs/decisions/0020-dev-container-files-get-their-own-family.md
[ec-0029]: https://github.com/musher-dev/engineering-conventions/blob/v0.8.0/docs/decisions/0029-the-local-environment-file-is-generated.md
