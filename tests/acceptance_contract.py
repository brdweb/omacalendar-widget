#!/usr/bin/env python3
"""Exercise candidate/stable acceptance decisions without publishing anything."""

from __future__ import annotations

import copy
import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "acceptance_gate", ROOT / "scripts/release/verify-acceptance.py"
)
assert SPEC and SPEC.loader
GATE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GATE)


class AcceptanceContractTest(unittest.TestCase):
    def setUp(self) -> None:
        self.record = json.loads((ROOT / "docs/stable-acceptance.json").read_text())
        # Actual owner evidence will be filled later; fixtures remain pending
        # independently so those real results do not change the test cases.
        self.record.update({"acceptedBy": None, "acceptedAt": None, "evidenceCommit": None})
        for gate in self.record["gates"].values():
            gate.update({"status": "pending", "evidence": ""})

    def completed(self) -> dict:
        record = copy.deepcopy(self.record)
        record.update({
            "acceptedBy": "Fixture tester", "acceptedAt": "2026-09-09T12:00:00Z",
            "evidenceCommit": "a" * 40,
        })
        for gate in record["gates"].values():
            gate.update({"status": "passed", "evidence": "Fixture result, not real release evidence"})
        return record

    def test_candidate_does_not_claim_stable_acceptance(self) -> None:
        self.assertFalse(GATE.verify_record(self.record, "v" + self.record["candidateVersion"]))

    def test_pending_record_cannot_release_stable(self) -> None:
        with self.assertRaisesRegex(GATE.GateError, "blocked by acceptance gates"):
            GATE.verify_record(self.record, "v0.1.0")

    def test_each_required_gate_needs_success_and_evidence(self) -> None:
        for key in GATE.REQUIRED_GATES:
            for status, evidence in (("pending", "recorded"), ("failed", "recorded"), ("passed", "")):
                record = self.completed()
                record["gates"][key] = {"status": status, "evidence": evidence}
                with self.subTest(gate=key, status=status, evidence=evidence):
                    with self.assertRaisesRegex(GATE.GateError, key):
                        GATE.verify_record(record, "v0.1.0")

    def test_cannot_omit_a_gate_or_reuse_another_release(self) -> None:
        record = self.completed()
        del record["gates"]["keyboard"]
        with self.assertRaisesRegex(GATE.GateError, "every required gate"):
            GATE.verify_record(record, "v0.1.0")
        with self.assertRaisesRegex(GATE.GateError, "stable tag must match"):
            GATE.verify_record(self.completed(), "v0.2.0")

    def test_passed_checkboxes_still_require_owner_and_commit(self) -> None:
        for key, value in (("acceptedBy", None), ("acceptedAt", None), ("evidenceCommit", "shortsha")):
            record = self.completed()
            record[key] = value
            with self.subTest(field=key), self.assertRaises(GATE.GateError):
                GATE.verify_record(record, "v0.1.0")
        self.assertTrue(GATE.verify_record(self.completed(), "v0.1.0"))

    def test_runtime_changes_invalidate_old_acceptance(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)

            def git(*arguments: str) -> str:
                return subprocess.check_output(
                    ["git", "-C", directory, *arguments], text=True, stderr=subprocess.DEVNULL,
                ).strip()

            git("init", "-q")
            git("config", "user.name", "Fixture")
            git("config", "user.email", "fixture@example.invalid")
            git("config", "commit.gpgsign", "false")
            (root / "manifest.json").write_text('{"version":"0.1.0-rc.4","id":"fixture"}\n')
            (root / "BarWidget.qml").write_text("Item {}\n")
            git("add", ".")
            git("commit", "-qm", "fixture candidate")
            commit = git("rev-parse", "HEAD")
            (root / "manifest.json").write_text('{"version":"0.1.0","id":"fixture"}\n')
            git("add", ".")
            git("commit", "-qm", "fixture stable metadata")
            GATE.verify_source(root, commit)
            (root / "BarWidget.qml").write_text("Item { visible: false }\n")
            git("add", ".")
            git("commit", "-qm", "fixture runtime change")
            with self.assertRaisesRegex(GATE.GateError, "runtime changed"):
                GATE.verify_source(root, commit)


if __name__ == "__main__":
    unittest.main(verbosity=2)
