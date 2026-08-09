"""Detect .config/ layout drift."""

from __future__ import annotations

from repo_governance import repo
from repo_governance.policies.config import violations as v
from repo_governance.violations import Report

CONFIG_DIR = ".config"

#: Configs the tool finds on its own. Everything else must be named by a
#: caller. Keep this list short -- each entry is a discovery dependency.
AUTO_DISCOVERED = {
    "lefthook.yml": "lefthook searches .config/ natively",
}

#: Gitignored personal overrides. Present or absent, never indexed.
LOCAL_OVERRIDES = {"lefthook-local.yml", "lefthook-local.yaml"}

#: Root filenames that would win lefthook's first-match-wins search.
SHADOWING = (
    "lefthook.yml", "lefthook.yaml", "lefthook.json", "lefthook.jsonc",
    "lefthook.toml", ".lefthook.yml", ".lefthook.yaml", ".lefthook.json",
    ".lefthook.jsonc", ".lefthook.toml",
)

#: Tool configs that belong in .config/ and must never appear at the root.
#: Git, Task and editor files are deliberately absent -- they are root-only
#: by the tools' own rules.
STRAY_ROOT_CONFIGS = (
    ".markdownlint.json", ".markdownlint.jsonc", ".markdownlint.yaml",
    ".markdownlint-cli2.jsonc", ".markdownlint-cli2.yaml",
    ".yamllint", ".yamllint.yml", ".yamllint.yaml",
    ".codespellrc", "codespell.cfg",
    "actionlint.yaml", "actionlint.yml",
    ".prettierrc", ".prettierrc.json", ".prettierrc.yaml",
    ".eslintrc", ".eslintrc.json", "eslint.config.js",
    ".stylelintrc", ".shellcheckrc",
)

#: Files scanned for explicit `.config/<name>` references.
CALLER_GLOBS = (
    "Taskfile.yml",
    "taskfiles/*.yml",
    "taskfiles/*.yaml",
    ".github/workflows/*.yml",
    ".github/workflows/*.yaml",
    ".config/lefthook.yml",
    ".devcontainer/scripts/**/*.sh",
)


def _caller_text() -> str:
    chunks = []
    for pattern in CALLER_GLOBS:
        for path in repo.glob(pattern):
            if path.is_file():
                chunks.append(path.read_text(encoding="utf-8"))
    return "\n".join(chunks)


def run() -> Report:
    report = Report(policy="config")
    root = repo.repo_root()
    config_dir = root / CONFIG_DIR

    if not config_dir.is_dir():
        report.add(v.missing_config_dir())
        return report

    index_path = config_dir / "README.md"
    index = index_path.read_text(encoding="utf-8") if index_path.is_file() else None
    if index is None:
        report.add(v.missing_index())

    callers = _caller_text()

    for path in sorted(config_dir.iterdir()):
        if not path.is_file():
            continue
        name = path.name
        if name == "README.md" or name in LOCAL_OVERRIDES:
            continue

        if name.startswith("."):
            report.add(v.dotted_filename(name))

        if index is not None and f"`{name}`" not in index:
            report.add(v.not_in_index(name))

        if name not in AUTO_DISCOVERED and f"{CONFIG_DIR}/{name}" not in callers:
            report.add(v.orphaned(name))

    for name in SHADOWING:
        if (root / name).is_file():
            report.add(v.shadowing_root_config(name))

    for name in STRAY_ROOT_CONFIGS:
        if (root / name).is_file():
            report.add(v.stray_root_config(name))

    return report
