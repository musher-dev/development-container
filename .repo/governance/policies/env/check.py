"""Detect env schemas that depart from the shared shape."""

from __future__ import annotations

import yaml

from governance import envschema, repo
from governance.policies.env import violations as v
from governance.reporting import Report


def run() -> Report:
    report = Report(policy="env")
    # Location is the layout policy's job; shape is checked wherever the file is.
    for path in repo.tracked_files():
        if path.rsplit("/", 1)[-1] != "env.schema.yaml" or not repo.exists(path):
            continue
        try:
            schema = repo.read_yaml(path)
        except yaml.YAMLError as error:
            report.add(v.malformed(path, f"not valid YAML ({error.__class__.__name__})"))
            continue
        for problem in envschema.problems(schema):
            report.add(v.malformed(path, problem))
    return report
