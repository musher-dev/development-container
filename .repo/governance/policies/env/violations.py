"""What can go wrong between the dev-environment schema and the stacks, and why.

The schema's own shape, its secrets and the Codespaces `secrets` block are
engineering-conventions' ENVS and DEVC rules. What stays here is specific to
this scaffold: the joins between .devcontainer/env.schema.yaml and the compose
stacks that read it, and the configs that repeat its values literally.
"""

from __future__ import annotations

from governance.reporting import Violation

DEV = "CONFIGURATION.md#environment-variables"


def undeclared_reference(name: str, where: str) -> Violation:
    return Violation(
        code="ENV-03",
        summary=f"compose reads ${{{name}}}, which the schema does not declare",
        reason=(
            "An undeclared variable is invisible to `repo env sync` "
            "and `repo env doctor`, so it silently takes its `:-default` and "
            "nobody is ever told a value was expected."
        ),
        fix=f"Declare {name} in .devcontainer/env.schema.yaml, or stop reading it.",
        where=where,
        docs=DEV,
    )


def unread_binding(name: str, stack: str) -> Violation:
    return Violation(
        code="ENV-03",
        summary=f"{name} lists consumer '{stack}', which never reads it",
        reason=(
            "`consumers` is what makes a requirement conditional on the stacks "
            "that are running. A consumer that does not read the value makes "
            "`repo env doctor` demand it for no reason."
        ),
        fix=f"Remove '{stack}' from {name}'s consumers, or read it in that stack's compose file.",
        where=".devcontainer/env.schema.yaml",
        docs=DEV,
    )


def unknown_stack(name: str, stack: str) -> Violation:
    return Violation(
        code="ENV-04",
        summary=f"{name} names consumer '{stack}', which is not a stack",
        reason="A consumer that does not exist can never be active, so the binding is never required.",
        fix=f"Use a directory name under .devcontainer/stacks/, or drop '{stack}'.",
        where=".devcontainer/env.schema.yaml",
        docs=DEV,
    )


def mirror_drift(name: str, path: str, value: str) -> Violation:
    return Violation(
        code="ENV-05",
        summary=f"{path} does not contain {name}'s value ({value!r})",
        reason=(
            "That file is native YAML with no env interpolation, so it repeats "
            "the credential literally. Changing one side alone leaves a stack "
            "that starts and then fails to authenticate."
        ),
        fix=f"Update {path} to match, or correct {name}'s mirrored_in list.",
        where=path,
        docs=DEV,
    )
