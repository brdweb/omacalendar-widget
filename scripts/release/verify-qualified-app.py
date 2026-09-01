#!/usr/bin/env python3
"""Verify the published OmaCalendar release qualified by this widget."""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable


ROOT = Path(__file__).resolve().parents[2]
APP_REPOSITORY = "brdweb/omacalendar"
DOMAIN_HEADER = "src/core/domain.h"
SEMVER = re.compile(
    r"^(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)"
    r"(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$"
)
SHA = re.compile(r"^[0-9a-f]{40}$")


class GateError(RuntimeError):
    """The qualified app release does not satisfy the release boundary."""


@dataclass(frozen=True)
class Expectations:
    app_version: str
    protocol_major: int
    minimum_protocol_minor: int


@dataclass(frozen=True)
class QualifiedApp:
    tag: str
    commit: str
    protocol_major: int
    protocol_minor: int
    published_at: str


def _object(value: Any, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise GateError(f"{label} must be a JSON object")
    return value


def _nonnegative_integer(value: Any, label: str) -> int:
    if type(value) is not int or value < 0:
        raise GateError(f"{label} must be a non-negative integer")
    return value


def load_expectations(root: Path = ROOT) -> Expectations:
    manifest = _object(
        json.loads((root / "manifest.json").read_text(encoding="utf-8")),
        "manifest.json",
    )
    release = _object(
        json.loads((root / "release.json").read_text(encoding="utf-8")),
        "release.json",
    )
    compatibility = _object(manifest.get("compatibility"), "manifest compatibility")

    app_version = release.get("testedOmaCalendarVersion")
    if not isinstance(app_version, str) or not SEMVER.fullmatch(app_version):
        raise GateError(
            "release.json testedOmaCalendarVersion must be canonical semantic versioning"
        )

    manifest_major = _nonnegative_integer(
        compatibility.get("omacalendarProtocolMajor"),
        "manifest OmaCalendar protocol major",
    )
    manifest_minor = _nonnegative_integer(
        compatibility.get("minimumOmaCalendarProtocolMinor"),
        "manifest minimum OmaCalendar protocol minor",
    )
    release_major = _nonnegative_integer(
        release.get("omacalendarProtocolMajor"),
        "release.json OmaCalendar protocol major",
    )
    release_minor = _nonnegative_integer(
        release.get("minimumOmaCalendarProtocolMinor"),
        "release.json minimum OmaCalendar protocol minor",
    )
    if release_major != manifest_major or release_minor != manifest_minor:
        raise GateError("release.json IPC compatibility must match manifest.json")
    return Expectations(app_version, release_major, release_minor)


def _run_gh(arguments: list[str]) -> str:
    environment = os.environ.copy()
    environment["MISE_QUIET"] = "1"
    result = subprocess.run(
        ["gh", "api", *arguments],
        check=False,
        env=environment,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode != 0:
        detail = result.stderr.strip() or "GitHub API request failed"
        raise GateError(detail)
    return result.stdout


def github_json(endpoint: str) -> dict[str, Any]:
    try:
        return _object(json.loads(_run_gh([endpoint])), f"GitHub response for {endpoint}")
    except json.JSONDecodeError as error:
        raise GateError(f"GitHub returned invalid JSON for {endpoint}") from error


def github_text(endpoint: str) -> str:
    return _run_gh(["-H", "Accept: application/vnd.github.raw+json", endpoint])


def _sha(value: Any, label: str) -> str:
    if not isinstance(value, str) or not SHA.fullmatch(value):
        raise GateError(f"{label} must be a full Git commit or object SHA")
    return value


def _protocol_constant(source: str, name: str) -> int:
    matches = re.findall(
        rf"^[ \t]*inline[ \t]+constexpr[ \t]+int[ \t]+{re.escape(name)}"
        rf"[ \t]*=[ \t]*([0-9]+);[ \t]*$",
        source,
        re.MULTILINE,
    )
    if len(matches) != 1:
        raise GateError(f"tagged {DOMAIN_HEADER} must define exactly one {name}")
    return int(matches[0])


def verify_qualified_app(
    expected: Expectations,
    request_json: Callable[[str], dict[str, Any]] = github_json,
    request_text: Callable[[str], str] = github_text,
) -> QualifiedApp:
    tag = f"v{expected.app_version}"
    ref_endpoint = f"repos/{APP_REPOSITORY}/git/ref/tags/{tag}"
    ref = request_json(ref_endpoint)
    if ref.get("ref") != f"refs/tags/{tag}":
        raise GateError(f"OmaCalendar {tag} did not resolve to the exact tag ref")
    ref_object = _object(ref.get("object"), "OmaCalendar tag ref object")
    if ref_object.get("type") != "tag":
        raise GateError(f"OmaCalendar {tag} must be an annotated Git tag")
    tag_sha = _sha(ref_object.get("sha"), "OmaCalendar annotated tag object")

    tag_object = request_json(f"repos/{APP_REPOSITORY}/git/tags/{tag_sha}")
    if tag_object.get("tag") != tag:
        raise GateError("OmaCalendar annotated tag object has the wrong tag name")
    verification = _object(tag_object.get("verification"), "tag signature verification")
    if verification.get("verified") is not True:
        raise GateError(f"GitHub did not verify the signature on OmaCalendar {tag}")
    target = _object(tag_object.get("object"), "OmaCalendar annotated tag target")
    if target.get("type") != "commit":
        raise GateError(f"OmaCalendar {tag} must resolve directly to a commit")
    commit_sha = _sha(target.get("sha"), "OmaCalendar tagged commit")

    release = request_json(f"repos/{APP_REPOSITORY}/releases/tags/{tag}")
    if release.get("tag_name") != tag:
        raise GateError("OmaCalendar GitHub release has the wrong tag name")
    published_at = release.get("published_at")
    if release.get("draft") is not False or not isinstance(published_at, str) or not published_at:
        raise GateError(f"OmaCalendar {tag} must have a published, non-draft GitHub release")

    source = request_text(
        f"repos/{APP_REPOSITORY}/contents/{DOMAIN_HEADER}?ref={commit_sha}"
    )
    protocol_major = _protocol_constant(source, "kIpcProtocolMajor")
    protocol_minor = _protocol_constant(source, "kIpcProtocolMinor")
    if protocol_major != expected.protocol_major:
        raise GateError(
            f"OmaCalendar {tag} exposes IPC major {protocol_major}, "
            f"expected {expected.protocol_major}"
        )
    if protocol_minor < expected.minimum_protocol_minor:
        raise GateError(
            f"OmaCalendar {tag} exposes IPC minor {protocol_minor}, below required "
            f"{expected.minimum_protocol_minor}"
        )

    final_ref = request_json(ref_endpoint)
    final_object = _object(final_ref.get("object"), "final OmaCalendar tag ref object")
    if final_object.get("type") != "tag" or final_object.get("sha") != tag_sha:
        raise GateError(f"OmaCalendar {tag} changed while its release was being verified")

    return QualifiedApp(
        tag,
        commit_sha,
        protocol_major,
        protocol_minor,
        published_at,
    )


def main() -> None:
    try:
        qualified = verify_qualified_app(load_expectations())
    except (GateError, json.JSONDecodeError, OSError) as error:
        raise SystemExit(f"qualified OmaCalendar release verification failed: {error}") from error
    print(
        f"Qualified {APP_REPOSITORY} {qualified.tag} at {qualified.commit}: "
        f"published {qualified.published_at}, IPC "
        f"{qualified.protocol_major}.{qualified.protocol_minor}"
    )


if __name__ == "__main__":
    main()
