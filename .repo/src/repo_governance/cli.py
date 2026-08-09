"""The `repo` command.

    repo check            run every policy
    repo config check     .config/ layout and liveness
    repo ports check      port declarations agree
    repo hooks check      local hooks and CI stay in step
"""

from __future__ import annotations

import argparse
import sys
from collections.abc import Callable

from repo_governance import __version__
from repo_governance.policies import config, hooks, ports
from repo_governance.violations import Report, render_reports

POLICIES: dict[str, Callable[[], Report]] = {
    "config": config.run,
    "ports": ports.run,
    "hooks": hooks.run,
}


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="repo",
        description="Structural policy checks for this repository.",
    )
    parser.add_argument("--version", action="version", version=f"repo {__version__}")
    sub = parser.add_subparsers(dest="group", required=True)

    run_all = sub.add_parser("check", help="run every policy")
    run_all.set_defaults(policies=list(POLICIES))

    for name in POLICIES:
        group = sub.add_parser(name, help=f"{name} policy")
        actions = group.add_subparsers(dest="action", required=True)
        actions.add_parser("check", help=f"run the {name} policy")
        group.set_defaults(policies=[name])

    return parser


def main(argv: list[str] | None = None) -> int:
    args = _build_parser().parse_args(argv)
    reports = [POLICIES[name]() for name in args.policies]
    return render_reports(reports)


if __name__ == "__main__":
    sys.exit(main())
