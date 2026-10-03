"""What can go wrong between the dev container and the declared product, and why."""

from __future__ import annotations

from governance.reporting import Violation

ADAPTERS = "LAYOUT.md#ecosystem-adapters"

_SILENT = (
    "Tools that name the product by path do not fail when the path is wrong: "
    "the mount lands on the bind mount instead. Agreement with the one "
    "declaration is the only thing that catches it."
)


def stray_workspace_mount(target: str, product: str | None) -> Violation:
    home = f"{product}/" if product else "a declared product directory"
    return Violation(
        code="LAYOUT-07",
        summary=f"devcontainer mount {target} is not under {home}",
        reason=_SILENT + " Build-output volumes belong to the product they cache.",
        fix=f"Point the mount inside {home}, or remove it.",
        where=".devcontainer/devcontainer.json",
        docs=ADAPTERS,
    )


def missing_editor_link(setting: str, entry: str) -> Violation:
    return Violation(
        code="LAYOUT-07",
        summary=f"devcontainer setting {setting} does not list {entry}",
        reason=(
            "The editor opens the repository root, one level above the product, "
            "so its language server finds no project unless it is linked."
        ),
        fix=f'Add "{entry}" to customizations.vscode.settings["{setting}"].',
        where=".devcontainer/devcontainer.json",
        docs=ADAPTERS,
    )
