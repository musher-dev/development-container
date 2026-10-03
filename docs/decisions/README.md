# Decisions

Architecture decision records for this repository: why the dev container scaffold is shaped the way it is. Each
record follows the decision-record convention,
[EC-0021][ec-decision]. Copy
[template.md](template.md) to start one.

A repository created from this template deletes this directory: these records are about the scaffold, not about
the repository that copies it.

| ID | Decision | Status |
| --- | --- | --- |
| [0001](0001-the-scaffold-is-published-as-a-pinned-image.md) | The scaffold is published as a pinned image, and the general rules live in engineering-conventions | accepted |
| [0002](0002-the-dev-env-file-is-generated-in-the-container.md) | The dev environment's .env is generated inside the container, and nothing runs on the host | accepted |
| [0003](0003-the-image-bakes-only-mise.md) | The image bakes only mise; every other CLI is a locked mise pin | accepted |

[ec-decision]: https://github.com/musher-dev/engineering-conventions/blob/v0.8.0/engineering-conventions/definitions/conventions/decisions/decision-records.md
