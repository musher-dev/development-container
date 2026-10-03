from __future__ import annotations

import pytest

from conftest import codes
from governance import globs
from governance.policies.paths import run

LEFTHOOK = ".config/lefthook.yml"


def test_clean_repo(make_repo):
    make_repo({LEFTHOOK: "pre-commit:\n  jobs:\n    - name: md\n      glob: '*.md'\n", "README.md": ""})
    assert run().violations == []


@pytest.mark.parametrize(
    ("pattern", "files", "expected"),
    [
        ("*.{yml,yaml}", ["a.yaml"], True),
        ("{docs/**,README.md}", ["docs/x.md"], False),
        ("{docs/**,README.md}", ["docs/x.md", "README.md"], True),
        (".github/workflows/*.yml", [".github/workflows/v.yaml"], False),
        ("**/*.rs", ["demo/src/main.rs"], True),
    ],
)
def test_matches(pattern, files, expected):
    assert globs.matches(pattern, files) is expected


def test_gitignore_style_anchors_anywhere():
    assert globs.matches("*.sh", ["a/b/c.sh"], gitignore_style=True)
    assert not globs.matches(".env", [".devcontainer/.env.example"], gitignore_style=True)


def test_gitattributes_pattern_for_untracked_file(make_repo):
    make_repo({".gitattributes": "* text=auto eol=lf\n.env text eol=lf\n"})
    assert codes(run()) == {"PATH-01"}


def test_paths_filter(make_repo):
    workflow = (
        "on: push\njobs:\n  a:\n    runs-on: x\n    steps:\n"
        "      - uses: dorny/paths-filter@v3\n        with:\n"
        "          filters: |\n            rust:\n              - 'crates/**'\n"
    )
    make_repo({".github/workflows/ci.yml": workflow})
    assert "PATH-01" in codes(run())


def test_stale_allowance(make_repo, monkeypatch):
    from governance.policies.paths import check

    monkeypatch.setattr(check, "UNTRACKED_OK", {"target/**": "build output"})
    make_repo({})
    assert codes(run()) == {"PATH-04"}
