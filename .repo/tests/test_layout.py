from __future__ import annotations

import json


from conftest import HOST_AGENT, codes
from governance.policies.layout import run

EMPTY = {".repo/repository.toml": '[layout]\nproduct = ""\n'}


def test_adapted_product_repo_is_clean(make_repo):
    make_repo(HOST_AGENT)
    assert run().violations == []


def test_template_state_is_clean(make_repo):
    make_repo(EMPTY)
    assert run().violations == []


def test_mount_outside_product(make_repo):
    devcontainer = json.loads(HOST_AGENT[".devcontainer/devcontainer.json"])
    devcontainer["mounts"] = ["source=x,target=/workspaces/${localWorkspaceFolderBasename}/target,type=volume"]
    make_repo({**HOST_AGENT, ".devcontainer/devcontainer.json": json.dumps(devcontainer)})
    assert codes(run()) == {"LAYOUT-07"}


def test_workspace_mount_without_product(make_repo):
    devcontainer = {"mounts": ["source=x,target=/workspaces/${localWorkspaceFolderBasename}/target,type=volume"]}
    make_repo({**EMPTY, ".devcontainer/devcontainer.json": json.dumps(devcontainer)})
    assert "LAYOUT-07" in codes(run())


def test_commented_mount_example_is_ignored(make_repo):
    devcontainer = (
        '{\n  "mounts": [\n'
        '    // "source=x,target=/workspaces/${localWorkspaceFolderBasename}/<product>/target,type=volume"\n'
        "  ]\n}\n"
    )
    make_repo({**EMPTY, ".devcontainer/devcontainer.json": devcontainer})
    assert run().violations == []


def test_editor_link_needs_the_manifest(make_repo):
    files = {k: v for k, v in HOST_AGENT.items() if k != "demo/Cargo.toml"}
    files[".devcontainer/devcontainer.json"] = json.dumps({"mounts": []})
    make_repo({**files, "demo/package.json": "{}"})
    assert run().violations == []


def test_missing_editor_link(make_repo):
    devcontainer = json.loads(HOST_AGENT[".devcontainer/devcontainer.json"])
    devcontainer["customizations"] = {}
    make_repo({**HOST_AGENT, ".devcontainer/devcontainer.json": json.dumps(devcontainer)})
    assert codes(run()) == {"LAYOUT-07"}
