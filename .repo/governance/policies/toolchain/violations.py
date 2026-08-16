"""What can go wrong with the image-baked toolchain, and why each rule exists."""

from __future__ import annotations

from governance.reporting import Violation

DOCS = "CONFIGURATION.md#runtimes--tools"

DOCKERFILE = ".devcontainer/Dockerfile"
DEVCONTAINER = ".devcontainer/devcontainer.json"

#: The diagnosis behind TC-01, stated once. It is long on purpose: the whole
#: point of moving these three tools into the Dockerfile is easy to mistake for
#: fussiness, and the next person to reach for the Feature deserves the actual
#: failure mode rather than "we don't do that here".
_WHY_NOT_A_FEATURE = (
    "The devcontainers-extra Features for bun, uv and go-task all install via "
    "nanolayer's gh-release helper, which lists a release's assets by calling "
    "api.github.com with no credentials "
    "(nanolayer/installers/gh_release/resolvers/asset_resolver.py). Codespaces "
    "build hosts and GitHub-hosted Actions runners share egress IP pools, so "
    "the 60 req/hr anonymous limit is routinely exhausted and the call 403s. "
    "Pinning the version does not help -- the pin only supplies the tag; the "
    "asset listing still hits the API. One failed Feature fails the entire "
    "image build, and Codespaces then drops the developer into a bare recovery "
    "container, so the symptom is 'task: command not found' rather than the "
    "real error."
)


def feature_reintroduced(feature: str, tool: str) -> Violation:
    return Violation(
        code="TC-01",
        summary=f"{tool} is declared as a Feature; it must be baked by the Dockerfile",
        reason=_WHY_NOT_A_FEATURE,
        fix=(
            f"Remove {feature!r} from the features block and pin {tool} with an "
            f"ARG in {DOCKERFILE} instead."
        ),
        where=DEVCONTAINER,
        docs=DOCS,
    )


def missing_arg(name: str, tool: str) -> Violation:
    return Violation(
        code="TC-02",
        summary=f"no pinned 'ARG {name}=<version>' for {tool}",
        reason=(
            "The ARG defaults are the single source of truth for what the image "
            "bakes. scripts/verify-toolchain.sh reads them back to assert the "
            "built container matches, so an absent or empty pin turns that CI "
            "check into a no-op."
        ),
        fix=f"Add `ARG {name}=<version>` to {DOCKERFILE}.",
        where=DOCKERFILE,
        docs=DOCS,
    )


def floating_arg(name: str, value: str) -> Violation:
    return Violation(
        code="TC-02",
        summary=f"ARG {name} is set to the floating value {value!r}",
        reason=(
            "Every other tool in this template is pinned to an exact version. A "
            "floating tag makes the image irreproducible and silently changes "
            "the toolchain under developers who rebuild on different days."
        ),
        fix=f"Replace {value!r} with an exact version in {DOCKERFILE}.",
        where=DOCKERFILE,
        docs=DOCS,
    )


def task_version_drift(dockerfile_version: str, ci_version: str, ci_path: str) -> Violation:
    return Violation(
        code="TC-03",
        summary=(
            f"task pinned to {dockerfile_version} in the Dockerfile but "
            f"{ci_version} in CI"
        ),
        reason=(
            "CI installs Task with arduino/setup-task rather than the dev "
            "container image, so the two pins are the same decision recorded "
            "twice. When they drift, a Taskfile change can pass locally and "
            "fail in CI (or the reverse) for reasons no diff explains."
        ),
        fix=(
            f"Set the same version in {DOCKERFILE} (ARG TASK_VERSION) and "
            f"{ci_path} (arduino/setup-task `version:`)."
        ),
        where=ci_path,
        docs=DOCS,
    )
