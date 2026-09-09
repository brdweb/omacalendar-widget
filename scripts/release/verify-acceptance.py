#!/usr/bin/env python3
"""Keep draft candidates separate from approval of a stable widget release."""

from __future__ import annotations

import argparse
import datetime
import json
import re
import subprocess
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
REQUIRED_GATES = {
    "automated", "artifacts", "install_upgrade_remove", "transactional_restore",
    "views_edges", "keyboard", "real_mutations", "resilience",
    "desktop_handoff", "mixed_scale_theme",
}


class GateError(RuntimeError):
    """Stable publication does not have complete acceptance evidence."""


def verify_record(record: dict[str, Any], tag: str) -> bool:
    if not re.fullmatch(r"v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?", tag):
        raise GateError("acceptance verification requires a release tag")
    gates = record.get("gates")
    if not isinstance(gates, dict) or set(gates) != REQUIRED_GATES:
        raise GateError("acceptance record must contain every required gate exactly once")
    for key, gate in gates.items():
        if not isinstance(gate, dict) or gate.get("status") not in {"pending", "failed", "passed"}:
            raise GateError(f"{key}: status must be pending, failed, or passed")
        if not isinstance(gate.get("evidence"), str):
            raise GateError(f"{key}: evidence must be a string")
    version = tag[1:]
    if "-" in version:
        if record.get("candidateVersion") != version:
            raise GateError("candidate tag must match the acceptance record")
        return False
    if record.get("stableVersion") != version:
        raise GateError("stable tag must match the acceptance record")
    pending = sorted(
        key for key, gate in gates.items()
        if gate["status"] != "passed" or not gate["evidence"].strip()
    )
    if pending:
        raise GateError("stable release blocked by acceptance gates: " + ", ".join(pending))
    if not isinstance(record.get("acceptedBy"), str) or not record["acceptedBy"].strip():
        raise GateError("stable release requires a named release owner")
    try:
        accepted_at = datetime.datetime.fromisoformat(record.get("acceptedAt", ""))
    except (TypeError, ValueError) as error:
        raise GateError("stable release requires an ISO 8601 acceptance timestamp") from error
    if accepted_at.tzinfo is None:
        raise GateError("acceptance timestamp must include its timezone")
    if not re.fullmatch(r"[0-9a-f]{40}", record.get("evidenceCommit") or ""):
        raise GateError("stable acceptance requires the full tested candidate commit")
    return True


def verify_source(root: Path, commit: str) -> None:
    def git(*args: str) -> str:
        result = subprocess.run(
            ["git", "-C", str(root), *args], check=False,
            capture_output=True, text=True,
        )
        if result.returncode:
            raise GateError("acceptance commit must exist in the release history")
        return result.stdout

    git("merge-base", "--is-ancestor", commit, "HEAD")
    changed = git("diff", "--name-only", commit, "HEAD", "--", "*.qml", "*.js")
    if changed.strip():
        raise GateError("widget runtime changed after acceptance; repeat the affected acceptance pass")
    previous = json.loads(git("show", f"{commit}:manifest.json"))
    current = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
    previous.pop("version", None)
    current.pop("version", None)
    if previous != current:
        raise GateError("widget manifest behavior changed after acceptance")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tag")
    arguments = parser.parse_args()
    try:
        record = json.loads((ROOT / "docs/stable-acceptance.json").read_text(encoding="utf-8"))
        stable = verify_record(record, arguments.tag)
        if stable:
            verify_source(ROOT, record["evidenceCommit"])
    except (GateError, OSError, json.JSONDecodeError) as error:
        raise SystemExit(f"acceptance verification failed: {error}") from error
    if stable:
        print(f"Stable acceptance passed for {arguments.tag}; evidence commit {record['evidenceCommit']}")
    else:
        print(f"{arguments.tag} is a draft candidate; manual acceptance remains pending")


if __name__ == "__main__":
    main()
