#!/usr/bin/env python3
"""Regression contracts for the qualified OmaCalendar release gate."""

from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
GATE_PATH = ROOT / "scripts" / "release" / "verify-qualified-app.py"
SPEC = importlib.util.spec_from_file_location("qualified_app_gate", GATE_PATH)
if SPEC is None or SPEC.loader is None:
    raise SystemExit("could not load qualified app release gate")
GATE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = GATE
SPEC.loader.exec_module(GATE)


TAG_SHA = "a" * 40
COMMIT_SHA = "b" * 40


def domain_header(major: int = 2, minor: int = 0) -> str:
    return (
        f"inline constexpr int kIpcProtocolMajor = {major};\n"
        f"inline constexpr int kIpcProtocolMinor = {minor};\n"
    )


class QualifiedAppContractTest(unittest.TestCase):
    def setUp(self) -> None:
        self.expected = GATE.Expectations("1.0.0-alpha", 2, 0)
        self.tag = "v1.0.0-alpha"
        self.ref_endpoint = (
            f"repos/{GATE.APP_REPOSITORY}/git/ref/tags/{self.tag}"
        )
        self.responses: dict[str, dict[str, Any]] = {
            self.ref_endpoint: {
                "ref": f"refs/tags/{self.tag}",
                "object": {"type": "tag", "sha": TAG_SHA},
            },
            f"repos/{GATE.APP_REPOSITORY}/git/tags/{TAG_SHA}": {
                "tag": self.tag,
                "verification": {"verified": True},
                "object": {"type": "commit", "sha": COMMIT_SHA},
            },
            f"repos/{GATE.APP_REPOSITORY}/releases/tags/{self.tag}": {
                "tag_name": self.tag,
                "draft": False,
                "published_at": "2026-08-31T12:17:43Z",
            },
        }

    def request_json(self, endpoint: str) -> dict[str, Any]:
        return self.responses[endpoint]

    def request_text(self, endpoint: str) -> str:
        self.assertEqual(
            endpoint,
            f"repos/{GATE.APP_REPOSITORY}/contents/{GATE.DOMAIN_HEADER}"
            f"?ref={COMMIT_SHA}",
        )
        return domain_header()

    def verify(self) -> Any:
        return GATE.verify_qualified_app(
            self.expected,
            self.request_json,
            self.request_text,
        )

    def test_accepts_verified_annotated_published_compatible_release(self) -> None:
        qualified = self.verify()
        self.assertEqual(qualified.commit, COMMIT_SHA)
        self.assertEqual((qualified.protocol_major, qualified.protocol_minor), (2, 0))

    def test_rejects_lightweight_tag(self) -> None:
        self.responses[self.ref_endpoint]["object"] = {
            "type": "commit",
            "sha": COMMIT_SHA,
        }
        with self.assertRaisesRegex(GATE.GateError, "annotated Git tag"):
            self.verify()

    def test_rejects_unverified_signature(self) -> None:
        tag_endpoint = f"repos/{GATE.APP_REPOSITORY}/git/tags/{TAG_SHA}"
        self.responses[tag_endpoint]["verification"] = {"verified": False}
        with self.assertRaisesRegex(GATE.GateError, "verify the signature"):
            self.verify()

    def test_rejects_non_commit_tag_target(self) -> None:
        tag_endpoint = f"repos/{GATE.APP_REPOSITORY}/git/tags/{TAG_SHA}"
        self.responses[tag_endpoint]["object"] = {"type": "tree", "sha": COMMIT_SHA}
        with self.assertRaisesRegex(GATE.GateError, "resolve directly to a commit"):
            self.verify()

    def test_rejects_draft_or_unpublished_release(self) -> None:
        release_endpoint = f"repos/{GATE.APP_REPOSITORY}/releases/tags/{self.tag}"
        for draft, published_at in ((True, "2026-08-31T12:17:43Z"), (False, None)):
            with self.subTest(draft=draft, published_at=published_at):
                self.responses[release_endpoint].update(
                    {"draft": draft, "published_at": published_at}
                )
                with self.assertRaisesRegex(GATE.GateError, "published, non-draft"):
                    self.verify()

    def test_rejects_incompatible_protocol_source(self) -> None:
        with self.assertRaisesRegex(GATE.GateError, "exposes IPC major 3"):
            GATE.verify_qualified_app(
                self.expected,
                self.request_json,
                lambda _endpoint: domain_header(major=3),
            )
        minimum_one = GATE.Expectations("1.0.0-alpha", 2, 1)
        with self.assertRaisesRegex(GATE.GateError, "below required 1"):
            GATE.verify_qualified_app(
                minimum_one,
                self.request_json,
                self.request_text,
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
