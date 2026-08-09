"""Repository location and the file readers the policies share."""

from __future__ import annotations

import json
import re
from functools import lru_cache
from pathlib import Path

import yaml


@lru_cache(maxsize=1)
def repo_root() -> Path:
    """The repository root.

    Walks up from the working directory looking for the marker files this
    template is guaranteed to have, so `repo check` works from any
    subdirectory the way git does.
    """
    here = Path.cwd().resolve()
    for candidate in (here, *here.parents):
        if (candidate / ".devcontainer").is_dir() and (candidate / ".git").exists():
            return candidate
    return here


def read_text(rel: str) -> str:
    return (repo_root() / rel).read_text(encoding="utf-8")


def read_yaml(rel: str):
    return yaml.safe_load(read_text(rel))


_LINE_COMMENT = re.compile(r"//[^\n]*")
_TRAILING_COMMA = re.compile(r",(\s*[}\]])")


def read_jsonc(rel: str):
    """Parse a JSON-with-comments file such as devcontainer.json.

    devcontainer.json is JSONC by specification, so `json.loads` cannot read
    it directly and this repo's copy is heavily commented on purpose.
    """
    raw = read_text(rel)
    out: list[str] = []
    in_string = escaped = False
    i = 0
    while i < len(raw):
        char = raw[i]
        if in_string:
            out.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            i += 1
            continue
        if char == '"':
            in_string = True
            out.append(char)
            i += 1
        elif raw.startswith("//", i):
            newline = raw.find("\n", i)
            i = len(raw) if newline < 0 else newline
        elif raw.startswith("/*", i):
            end = raw.find("*/", i)
            i = len(raw) if end < 0 else end + 2
        else:
            out.append(char)
            i += 1
    return json.loads(_TRAILING_COMMA.sub(r"\1", "".join(out)))


def exists(rel: str) -> bool:
    return (repo_root() / rel).exists()


def glob(pattern: str) -> list[Path]:
    return sorted(repo_root().glob(pattern))


def rel(path: Path) -> str:
    return path.relative_to(repo_root()).as_posix()
