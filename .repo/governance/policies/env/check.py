"""Detect drift between the dev-environment schema and the stacks that read it."""

from __future__ import annotations

import re

from governance import envtools, repo
from governance.policies.env import violations as v
from governance.reporting import Report

#: `${VAR}`, `${VAR:-default}`, `${VAR:?err}` in a compose file.
_REFERENCE = re.compile(r"\$\{([A-Z][A-Z0-9_]*)[:?}-]")


def _compose_references() -> dict[str, set[str]]:
    """Variables each stack's compose file reads, keyed by stack name."""
    found: dict[str, set[str]] = {}
    for path in repo.glob(f"{envtools.STACKS}/*/compose.yaml"):
        found[path.parent.name] = set(_REFERENCE.findall(path.read_text(encoding="utf-8")))
    return found


def run() -> Report:
    report = Report(policy="env")
    if not repo.exists(envtools.SCHEMA):
        return report

    bindings = envtools.bindings()
    references = _compose_references()
    stacks = set(envtools.stack_profiles())

    for stack, names in sorted(references.items()):
        for name in sorted(names - set(bindings)):
            report.add(v.undeclared_reference(name, f"{envtools.STACKS}/{stack}/compose.yaml"))

    for name, binding in bindings.items():
        if not isinstance(binding, dict):
            continue
        for stack in binding.get("consumers") or []:
            if stack not in stacks:
                report.add(v.unknown_stack(name, stack))
            elif name not in references.get(stack, set()):
                report.add(v.unread_binding(name, stack))
        local_default = binding.get("local_default")
        for mirror in binding.get("mirrored_in") or []:
            rel = f".devcontainer/{mirror}"
            if not repo.exists(rel) or str(local_default) not in repo.read_text(rel):
                report.add(v.mirror_drift(name, rel, str(local_default)))

    return report
