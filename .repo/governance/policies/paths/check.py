"""Detect configured globs that match nothing.

What engineering-conventions does not yet cover: .gitattributes, dorny/paths-filter
and .claude/rules `paths:` globs. Lefthook globs are HOOKS-11, workflow and
Dependabot directories GHA-45 and REPO-22, and Taskfile path vars TASK-08.
"""

from __future__ import annotations

import yaml

from governance import globs, repo
from governance.policies.paths import violations as v
from governance.reporting import Report

GITATTRIBUTES = ".gitattributes"

#: Patterns that may legitimately match no tracked file (generated or
#: gitignored output), each with a reason. Empty until something needs it.
UNTRACKED_OK: dict[str, str] = {}


def _walk(node: object):
    yield node
    if isinstance(node, dict):
        for value in node.values():
            yield from _walk(value)
    elif isinstance(node, list):
        for value in node:
            yield from _walk(value)


def _yaml_files(*patterns: str):
    for pattern in patterns:
        for path in repo.glob(pattern):
            if path.is_file():
                yield repo.rel(path), yaml.safe_load(path.read_text(encoding="utf-8"))


def _glob_sources() -> list[tuple[str, str, bool]]:
    """(source, pattern, gitignore_style) for every glob a tool scopes itself by."""
    found: list[tuple[str, str, bool]] = []
    if repo.exists(GITATTRIBUTES):
        for line in repo.read_text(GITATTRIBUTES).splitlines():
            if line.strip() and not line.lstrip().startswith("#"):
                found.append((GITATTRIBUTES, line.split()[0], True))
    for source, doc in _yaml_files(".github/workflows/*.yml", ".github/workflows/*.yaml"):
        for node in _walk(doc):
            if isinstance(node, dict) and str(node.get("uses", "")).startswith("dorny/paths-filter@"):
                filters = (node.get("with") or {}).get("filters")
                parsed = yaml.safe_load(filters) if isinstance(filters, str) else filters
                for name, patterns in (parsed or {}).items():
                    for pattern in patterns if isinstance(patterns, list) else [patterns]:
                        if isinstance(pattern, str):
                            found.append((f"{source} paths-filter `{name}`", pattern, False))
    for path in repo.glob(".claude/rules/*.md"):
        text = path.read_text(encoding="utf-8")
        if text.startswith("---\n") and "\n---" in text[4:]:
            front = yaml.safe_load(text[4:].split("\n---", 1)[0]) or {}
            for pattern in front.get("paths", []) if isinstance(front, dict) else []:
                found.append((repo.rel(path), pattern, False))
    return found


def run() -> Report:
    report = Report(policy="paths")
    files = repo.tracked_files()

    used: set[str] = set()
    for source, pattern, gitignore_style in _glob_sources():
        if pattern in UNTRACKED_OK:
            used.add(pattern)
        elif not globs.matches(pattern, files, gitignore_style):
            report.add(v.glob_matches_nothing(source, pattern))

    for pattern in sorted(set(UNTRACKED_OK) - used):
        report.add(v.stale_allowance(pattern))

    return report
