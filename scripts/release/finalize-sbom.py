#!/usr/bin/env python3
"""Complete the widget archive's SPDX source-file inventory; no runtime SBOM."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re


TOOL = "Tool: omacalendar-widget-finalize-sbom-1"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def finalize(document: dict, stage: Path, version: str) -> dict:
    require(re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?", version) is not None,
            "invalid widget version")
    require(document.get("spdxVersion") == "SPDX-2.3", "expected SPDX-2.3 input")
    require(document.get("SPDXID") == "SPDXRef-DOCUMENT", "missing document identity")
    prefix = f"omacalendar-widget-{version}/"
    source = stage / prefix
    manifest = json.loads((source / "manifest.json").read_text())
    require(manifest.get("id") == "org.omacalendar.widget" and manifest.get("version") == version,
            "source manifest does not identify the requested widget version")
    require((source / "LICENSE").read_text().startswith("MIT License\n"), "review widget license change")
    paths = {path.relative_to(stage).as_posix(): path for path in stage.rglob("*")
             if path.is_file() and not path.is_symlink()}
    require(all(name.startswith(prefix) for name in paths), "stage contains unrelated payload files")
    for name in ("BarWidget.qml", "Panel.qml", "OmaCalendarClient.qml", "release.json"):
        require(prefix + name in paths, f"missing required widget source: {name}")
    packages = document.setdefault("packages", [])
    roots = [item for item in packages if item["SPDXID"].startswith("SPDXRef-DocumentRoot-")]
    require(len(roots) == 1, "expected one Syft directory-root package")
    root = roots[0]
    root.update(name="omacalendar-widget", versionInfo=version, primaryPackagePurpose="SOURCE",
                downloadLocation=f"https://github.com/brdweb/omacalendar-widget/releases/tag/v{version}",
                filesAnalyzed=True, licenseDeclared="MIT", licenseConcluded="NOASSERTION",
                licenseInfoFromFiles=["NOASSERTION"], copyrightText="NOASSERTION")
    scope = ("Scope: complete regular-file contents of the widget source archive. Symlink entries are not "
             "independent file contents. No provider libraries or runtime dependencies are bundled. Excludes "
             "the separately installed OmaCalendar native daemon/app, Quickshell, Qt, Omarchy and their "
             "transitive dependencies. Any scanner-identified build/test tooling describes source metadata, "
             "not an installed runtime dependency graph. License conclusions are NOASSERTION; consult LICENSE.")
    root["comment"] = scope
    document["name"] = f"omacalendar-widget-{version}-source"
    if TOOL not in document["creationInfo"]["creators"]:
        document["creationInfo"]["creators"].append(TOOL)
    document["annotations"] = [item for item in document.get("annotations", []) if item.get("annotator") != TOOL]
    document["annotations"].append({"annotationDate": document["creationInfo"]["created"], "annotationType": "OTHER",
                                    "annotator": TOOL, "comment": scope})
    old_files = {}
    for item in document.get("files", []):
        path = PurePosixPath(item["fileName"])
        require(not path.is_absolute() and ".." not in path.parts, "unsafe source file path")
        name = str(path)
        require(name in paths, f"SPDX describes missing/non-regular source: {name}")
        require(name not in old_files, "duplicate normalized source file path")
        old_files[name] = item
    files = []
    for name, path in sorted(paths.items()):
        data = path.read_bytes()
        item = dict(old_files.get(name, {}))
        item.update(fileName=name, SPDXID=item.get("SPDXID", "SPDXRef-File-" + hashlib.sha256(name.encode()).hexdigest()[:24]),
                    checksums=[{"algorithm": algorithm, "checksumValue": hashlib.new(digest, data).hexdigest()}
                               for algorithm, digest in (("SHA1", "sha1"), ("SHA256", "sha256"))],
                    licenseConcluded="NOASSERTION", licenseInfoInFiles=["NOASSERTION"], copyrightText="NOASSERTION")
        files.append(item)
    document["files"] = files
    sha1s = sorted(item["checksums"][0]["checksumValue"] for item in files)
    root["packageVerificationCode"] = {"packageVerificationCodeValue": hashlib.sha1("".join(sha1s).encode()).hexdigest()}
    relationships = document.setdefault("relationships", [])
    relationships.extend({"spdxElementId": root["SPDXID"], "relationshipType": "CONTAINS", "relatedSpdxElement": item["SPDXID"]}
                         for item in files)
    document["relationships"] = list({json.dumps(item, sort_keys=True): item for item in relationships}.values())
    ids = [document["SPDXID"]] + [item["SPDXID"] for item in packages + files]
    require(len(ids) == len(set(ids)), "duplicate SPDX identifier")
    for relationship in document["relationships"]:
        require(relationship["spdxElementId"] in ids and relationship["relatedSpdxElement"] in ids,
                "dangling or unsupported external SPDX relationship")
    return document


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--stage", type=Path, required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        result = finalize(json.loads(args.input.read_text()), args.stage, args.version)
    except (ValueError, KeyError, OSError) as error:
        parser.exit(1, f"Widget SBOM finalization failed: {error}\n")
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(f"Finalized widget {args.version} SPDX: {len(result['files'])} hashed source files")


if __name__ == "__main__":
    main()
