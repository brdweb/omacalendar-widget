#!/usr/bin/env python3
"""Portable contracts for the committed marketplace preview."""

from __future__ import annotations

import importlib.util
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VALIDATOR_PATH = ROOT / "tools" / "preview" / "validate_preview.py"
SPEC = importlib.util.spec_from_file_location("preview_validator", VALIDATOR_PATH)
if SPEC is None or SPEC.loader is None:
    raise SystemExit("could not load preview validator")
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)

FIXTURE_PATH = ROOT / "tools" / "preview" / "fake_preview_daemon.py"
FIXTURE_SPEC = importlib.util.spec_from_file_location("preview_fixture", FIXTURE_PATH)
if FIXTURE_SPEC is None or FIXTURE_SPEC.loader is None:
    raise SystemExit("could not load preview fixture")
FIXTURE = importlib.util.module_from_spec(FIXTURE_SPEC)
FIXTURE_SPEC.loader.exec_module(FIXTURE)


def main() -> None:
    preview_path = ROOT / "preview.png"
    width, height, chunks = VALIDATOR.inspect_png(preview_path)
    committed_ocr = VALIDATOR.inspect_ocr(preview_path)
    if width * height > 40_000_000:
        raise SystemExit("preview exceeds the marketplace pixel limit")
    if any(chunk in chunks for chunk in ("eXIf", "iTXt", "tEXt", "zTXt", "tIME")):
        raise SystemExit("preview retains author or workstation metadata")

    fixture = (ROOT / "tools" / "preview" / "fake_preview_daemon.py").read_text()
    for label in ("Release milestone", "Design review", "Product planning", "Focus block"):
        if label not in fixture:
            raise SystemExit(f"preview fixture is missing synthetic label: {label}")
    if re.search(r"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}", fixture, re.IGNORECASE):
        raise SystemExit("preview fixture contains an email address")

    snapshot = FIXTURE.preview_snapshot()
    events = {event["id"]: event for event in snapshot["events"]}
    expected_fixture_allowlist = {
        snapshot["activeCalendarSet"]["name"],
        events["release-milestone"]["title"],
        events["design-review"]["title"],
        events["design-review"]["location"],
        events["product-planning"]["title"],
        events["focus-block"]["title"],
    }
    if set(VALIDATOR.SYNTHETIC_FIXTURE_TEXT_ALLOWLIST) != expected_fixture_allowlist:
        raise SystemExit("OCR allowlist is not synchronized with the visible preview fixture")

    injected_ocr = committed_ocr + "\nPrivate oncology appointment for Alice"
    try:
        VALIDATOR.validate_ocr_text(injected_ocr)
    except SystemExit as error:
        if "outside the explicit synthetic preview allowlist" not in str(error):
            raise
    else:
        raise SystemExit("unexpected private appointment text passed OCR validation")

    capture = (ROOT / "tools" / "preview" / "capture-preview.sh").read_text()
    if re.search(r"(?:^|\s)(?:HOME|home|CODEX_HOME)=", capture, re.MULTILINE):
        raise SystemExit("preview capture must not repurpose a home environment variable")
    print(
        f"Preview contract passed: {width}x{height}, metadata-free synthetic "
        "fixture with strict allowlisted OCR labels"
    )


if __name__ == "__main__":
    main()
