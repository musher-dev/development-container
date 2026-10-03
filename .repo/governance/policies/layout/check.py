"""Detect dev container settings that point outside the declared product directory.

The rest of the layout contract -- the declaration, the root holding no product
content, Dependabot and Taskfile paths, env schema placement -- is
engineering-conventions' REPO-14..21 and ENVS-01/02. What stays here reads the
dev container configuration, which is specific to this scaffold.
"""

from __future__ import annotations

from governance import repo
from governance.policies.layout import violations as v
from governance.reporting import Report

DEVCONTAINER = ".devcontainer/devcontainer.json"
WORKSPACE_PREFIX = "/workspaces/${localWorkspaceFolderBasename}/"

#: VS Code list settings that must name the product, keyed by the manifest
#: that marks its ecosystem. Only Rust's is enforced: it is the adapter proven
#: in the org (host-agent). The rest are "verify on first adoption" in LAYOUT.md.
EDITOR_LINKS = {
    "Cargo.toml": {"rust-analyzer.linkedProjects": "{product}/Cargo.toml"},
}


def _mount_targets(devcontainer: dict) -> list[str]:
    targets = []
    for mount in devcontainer.get("mounts", []):
        if isinstance(mount, dict):
            target = mount.get("target", "")
        else:
            parts = dict(p.split("=", 1) for p in str(mount).split(",") if "=" in p)
            target = parts.get("target", parts.get("destination", parts.get("dst", "")))
        if target.startswith(WORKSPACE_PREFIX):
            targets.append(target)
    return targets


def run() -> Report:
    report = Report(policy="layout")
    if not repo.exists(DEVCONTAINER):
        return report
    product = repo.product()
    devcontainer = repo.read_jsonc(DEVCONTAINER)

    for target in _mount_targets(devcontainer):
        inside = target.removeprefix(WORKSPACE_PREFIX)
        if product is None or not (inside == product or inside.startswith(f"{product}/")):
            report.add(v.stray_workspace_mount(target, product))
    if product is None:
        return report

    settings = devcontainer.get("customizations", {}).get("vscode", {}).get("settings", {})
    for manifest, links in EDITOR_LINKS.items():
        if not repo.exists(f"{product}/{manifest}"):
            continue
        for setting, template in links.items():
            entry = template.format(product=product)
            if entry not in settings.get(setting, []):
                report.add(v.missing_editor_link(setting, entry))
    return report
