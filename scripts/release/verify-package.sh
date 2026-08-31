#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 SOURCE_ARCHIVE MAJOR.MINOR.PATCH[-PRERELEASE]" >&2
  exit 2
fi

source_archive=$1
release_version=$2
if [[ ! ${release_version} =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z]+([.-][0-9A-Za-z]+)*)?$ ]]; then
  echo "release version must be MAJOR.MINOR.PATCH[-PRERELEASE]" >&2
  exit 2
fi
if [[ ! -f ${source_archive} ]]; then
  echo "source archive does not exist: ${source_archive}" >&2
  exit 2
fi

python3 - "${source_archive}" "${release_version}" <<'PY'
from __future__ import annotations

import gzip
import io
import json
import pathlib
import sys
import tarfile


archive = pathlib.Path(sys.argv[1])
version = sys.argv[2]
expected_root = f"omacalendar-widget-{version}"
required = {
    "manifest.json",
    "release.json",
    "BarWidget.qml",
    "Panel.qml",
    "OmaCalendarClient.qml",
    "CalendarModel.js",
    "LICENSE",
    "README.md",
}

header = archive.read_bytes()[:10]
if len(header) < 10 or header[:2] != b"\x1f\x8b":
    raise SystemExit("release archive is not gzip data")
if header[4:8] != b"\x00\x00\x00\x00":
    raise SystemExit("gzip header contains a non-deterministic timestamp")

with gzip.open(archive, "rb") as compressed:
    tar_bytes = compressed.read()
with tarfile.open(fileobj=io.BytesIO(tar_bytes), mode="r:") as package:
    members = package.getmembers()
    relative_names: set[str] = set()
    for member in members:
        path = pathlib.PurePosixPath(member.name)
        if path.is_absolute() or ".." in path.parts:
            raise SystemExit(f"unsafe archive path: {member.name}")
        if not path.parts or path.parts[0] != expected_root:
            raise SystemExit(f"archive entry escaped the package root: {member.name}")
        if member.isdev() or member.issym() or member.islnk():
            raise SystemExit(f"unsupported archive entry type: {member.name}")
        if len(path.parts) > 1:
            relative_names.add(pathlib.PurePosixPath(*path.parts[1:]).as_posix())

    missing = sorted(required - relative_names)
    if missing:
        raise SystemExit(f"release archive is missing: {', '.join(missing)}")
    if any(name == ".git" or name.startswith(".git/") for name in relative_names):
        raise SystemExit("release archive contains Git internals")

    manifest_member = package.getmember(f"{expected_root}/manifest.json")
    manifest_file = package.extractfile(manifest_member)
    if manifest_file is None:
        raise SystemExit("release archive manifest is unreadable")
    manifest = json.load(manifest_file)
    release_member = package.getmember(f"{expected_root}/release.json")
    release_file = package.extractfile(release_member)
    if release_file is None:
        raise SystemExit("release archive metadata is unreadable")
    release = json.load(release_file)

if manifest.get("id") != "org.omacalendar.widget":
    raise SystemExit("release archive changed the plugin manifest ID")
if manifest.get("version") != version:
    raise SystemExit("release archive version does not match its filename")
compatibility = manifest.get("compatibility", {})
if compatibility.get("omacalendarProtocolMajor") != 2:
    raise SystemExit("release archive does not require OmaCalendar IPC major 2")
if release.get("widgetVersion") != version:
    raise SystemExit("release archive metadata version does not match its filename")
if release.get("omacalendarProtocolMajor") != 2:
    raise SystemExit("release archive metadata does not require OmaCalendar IPC major 2")
if not release.get("testedOmaCalendarVersion"):
    raise SystemExit("release archive metadata omits its tested app version")

print(f"verified deterministic release archive structure for {version}")
PY
