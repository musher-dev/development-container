"""What can go wrong with an env schema, and why the rule exists."""

from __future__ import annotations

from governance.reporting import Violation

DOCS = "LAYOUT.md#the-env-contract"


def malformed(path: str, problem: str) -> Violation:
    return Violation(
        code="ENV-01",
        summary=f"{path}: {problem}",
        reason=(
            "The schema is the contract other tools read -- generators, parity "
            "checks, the catalogue. One shape across every Musher repo is what "
            "lets them read any repo's schema without a special case."
        ),
        fix="Give every binding a `type`, a `sensitivity` (public|internal|secret) and a `description`.",
        where=path,
        docs=DOCS,
    )
