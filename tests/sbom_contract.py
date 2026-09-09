#!/usr/bin/env python3
"""Offline contract tests for the widget's shipped-source SPDX finalizer."""
from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("widget_sbom", Path(__file__).resolve().parents[1] / "scripts/release/finalize-sbom.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class SourceSbomTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory(prefix="widget-sbom-test-")
        self.addCleanup(self.tmp.cleanup)
        self.stage = Path(self.tmp.name)
        self.source = self.stage / "omacalendar-widget-0.1.0-rc.3"
        self.source.mkdir()
        (self.source / "manifest.json").write_text(json.dumps({"id": "org.omacalendar.widget", "version": "0.1.0-rc.3"}))
        (self.source / "LICENSE").write_text("MIT License\n")
        for name in ("BarWidget.qml", "Panel.qml", "OmaCalendarClient.qml", "release.json"):
            (self.source / name).write_text("fixture")
        self.document = {"spdxVersion": "SPDX-2.3", "dataLicense": "CC0-1.0", "SPDXID": "SPDXRef-DOCUMENT",
                         "name": "stage", "documentNamespace": "https://example.test/sbom/fixture",
                         "creationInfo": {"created": "2026-09-08T00:00:00Z", "creators": ["Tool: syft-test"]},
                         "packages": [{"name": "stage", "SPDXID": "SPDXRef-DocumentRoot-stage", "downloadLocation": "NOASSERTION"}],
                         "relationships": [{"spdxElementId": "SPDXRef-DOCUMENT", "relationshipType": "DESCRIBES", "relatedSpdxElement": "SPDXRef-DocumentRoot-stage"}]}

    def finish(self) -> dict:
        return module.finalize(self.document, self.stage, "0.1.0-rc.3")

    def test_complete_identity_hashes_graph_and_scope(self) -> None:
        result = self.finish()
        self.assertEqual(len(result["packages"]), 1)
        self.assertEqual(result["packages"][0]["name"], "omacalendar-widget")
        self.assertEqual(result["packages"][0]["versionInfo"], "0.1.0-rc.3")
        self.assertEqual(len(result["files"]), 6)
        self.assertEqual(len(result["relationships"]), 7)
        for item in result["files"]:
            self.assertEqual(item["checksums"][1]["checksumValue"], hashlib.sha256((self.stage / item["fileName"]).read_bytes()).hexdigest())
        self.assertIn("Excludes the separately installed OmaCalendar", result["annotations"][-1]["comment"])

    def test_placeholder_hash_replaced_without_losing_id(self) -> None:
        self.document["files"] = [{"fileName": self.source.name + "/Panel.qml", "SPDXID": "SPDXRef-existing",
                                   "checksums": [{"algorithm": "SHA1", "checksumValue": "0" * 40}]}]
        item = next(item for item in self.finish()["files"] if item["fileName"].endswith("/Panel.qml"))
        self.assertEqual(item["SPDXID"], "SPDXRef-existing")
        self.assertNotEqual(item["checksums"][0]["checksumValue"], "0" * 40)

    def test_version_mismatch_rejected(self) -> None:
        (self.source / "manifest.json").write_text('{"id":"org.omacalendar.widget","version":"0.1.0-rc.1"}')
        with self.assertRaisesRegex(ValueError, "requested widget version"):
            self.finish()

    def test_missing_runtime_source_rejected(self) -> None:
        (self.source / "Panel.qml").unlink()
        with self.assertRaisesRegex(ValueError, "missing required widget source"):
            self.finish()

    def test_unsafe_or_missing_spdx_path_rejected(self) -> None:
        for name in ("../outside", "/etc/passwd", "absent"):
            with self.subTest(name=name), self.assertRaises(ValueError):
                self.document["files"] = [{"fileName": name, "SPDXID": "SPDXRef-file"}]
                self.finish()

    def test_unrelated_stage_payload_rejected(self) -> None:
        (self.stage / "unrelated").write_text("not shipped")
        with self.assertRaisesRegex(ValueError, "unrelated payload"):
            self.finish()

    def test_symlink_not_read_as_external_file(self) -> None:
        (self.source / "external").symlink_to("/etc/passwd")
        self.assertEqual(len(self.finish()["files"]), 6)

    def test_dangling_graph_rejected(self) -> None:
        self.document["relationships"].append({"spdxElementId": "SPDXRef-DOCUMENT", "relationshipType": "DESCRIBES", "relatedSpdxElement": "SPDXRef-missing"})
        with self.assertRaisesRegex(ValueError, "dangling"):
            self.finish()


if __name__ == "__main__":
    unittest.main()
