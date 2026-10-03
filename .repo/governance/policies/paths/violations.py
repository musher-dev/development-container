"""What can go wrong with configured path references, and why the rule exists."""

from __future__ import annotations

from governance.reporting import Violation

DOCS = "LAYOUT.md#why-moves-fail-silently"

_WHY = (
    "A glob, directory or path that names nothing does not fail -- the hook "
    "skips, the job scopes to nothing, the setting is ignored. After a move "
    "that is indistinguishable from success, so it has to be checked."
)


def glob_matches_nothing(source: str, pattern: str) -> Violation:
    return Violation(
        code="PATH-01",
        summary=f"`{pattern}` matches no tracked file",
        reason=_WHY + " A literal brace alternative must match on its own.",
        fix=f"Point `{pattern}` at what it is meant to scope, or delete it.",
        where=source,
        docs=DOCS,
    )


def stale_allowance(pattern: str) -> Violation:
    return Violation(
        code="PATH-04",
        summary=f"UNTRACKED_OK entry `{pattern}` is not used by any source",
        reason="An allowance that outlives what it excused is a hole nobody remembers opening.",
        fix=f"Remove `{pattern}` from UNTRACKED_OK in .repo/governance/policies/paths/check.py.",
        where=".repo/governance/policies/paths/check.py",
        docs=DOCS,
    )
