#!/usr/bin/env python3
"""Validate the privacy and marketplace constraints of the widget preview."""

from __future__ import annotations

import re
import struct
import subprocess
import sys
import zlib
from pathlib import Path


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
MAX_BYTES = 50 * 1024 * 1024
MAX_PIXELS = 40_000_000
# PLTE/tRNS are pixel representation, not author or workstation metadata.
ALLOWED_CHUNKS = {b"IHDR", b"PLTE", b"tRNS", b"IDAT", b"IEND"}
EXPECTED_TEXT = (
    "monday august 31",
    "all calendars",
    "release milestone",
    "design review",
    "product planning",
    "focus block",
    "today",
    "search",
    "accounts",
)
PRIVATE_TEXT_PATTERNS = (
    re.compile(r"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}", re.IGNORECASE),
    re.compile(r"/(?:home|users)/", re.IGNORECASE),
    re.compile(r"\b(?:gmail|outlook|icloud)\.com\b", re.IGNORECASE),
)


def fail(message: str) -> None:
    raise SystemExit(f"preview validation failed: {message}")


def inspect_png(path: Path) -> tuple[int, int, list[str]]:
    if path.is_symlink() or not path.is_file():
        fail("preview must be a regular, non-symlink file")
    size = path.stat().st_size
    if size <= 0 or size > MAX_BYTES:
        fail("preview must be non-empty and no larger than 50 MB")

    payload = path.read_bytes()
    if not payload.startswith(PNG_SIGNATURE):
        fail("preview must be a PNG")

    offset = len(PNG_SIGNATURE)
    chunks: list[bytes] = []
    width = height = 0
    while offset < len(payload):
        if offset + 12 > len(payload):
            fail("preview contains a truncated PNG chunk")
        length = struct.unpack(">I", payload[offset : offset + 4])[0]
        chunk_type = payload[offset + 4 : offset + 8]
        end = offset + 12 + length
        if end > len(payload):
            fail("preview contains a truncated PNG payload")
        chunk_data = payload[offset + 8 : offset + 8 + length]
        expected_crc = struct.unpack(">I", payload[offset + 8 + length : end])[0]
        actual_crc = zlib.crc32(chunk_type + chunk_data) & 0xFFFFFFFF
        if actual_crc != expected_crc:
            fail(f"preview has an invalid {chunk_type.decode('ascii', 'replace')} CRC")
        if chunk_type not in ALLOWED_CHUNKS:
            fail(
                "preview contains metadata or an unexpected ancillary chunk: "
                + chunk_type.decode("ascii", "replace")
            )
        if chunk_type == b"IHDR":
            if length != 13:
                fail("preview has an invalid IHDR")
            width, height = struct.unpack(">II", chunk_data[:8])
        chunks.append(chunk_type)
        offset = end
        if chunk_type == b"IEND":
            break

    if offset != len(payload) or not chunks or chunks[-1] != b"IEND":
        fail("preview has trailing data or no IEND chunk")
    if chunks.count(b"IHDR") != 1 or b"IDAT" not in chunks:
        fail("preview is missing required PNG chunks")
    if width < 640 or height < 400:
        fail(f"preview is too small to read comfortably: {width}x{height}")
    if width * height > MAX_PIXELS:
        fail("preview exceeds the marketplace 40-megapixel limit")
    return width, height, [chunk.decode("ascii") for chunk in chunks]


def inspect_ocr(path: Path) -> str:
    result = subprocess.run(
        ["tesseract", str(path), "stdout"],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    text = result.stdout.strip()
    normalized = re.sub(r"[^a-z0-9]+", " ", text.lower()).strip()
    for expected in EXPECTED_TEXT:
        if expected not in normalized:
            fail(f"OCR did not find the synthetic label {expected!r}")
    for pattern in PRIVATE_TEXT_PATTERNS:
        if pattern.search(text):
            fail(f"OCR found text matching the private-data pattern {pattern.pattern!r}")
    return text


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: validate_preview.py PREVIEW.png")
    path = Path(sys.argv[1]).resolve()
    width, height, chunks = inspect_png(path)
    inspect_ocr(path)
    print(
        f"Preview validated: {width}x{height}, {path.stat().st_size} bytes, "
        f"chunks={','.join(chunks)}, OCR contains only expected synthetic labels"
    )


if __name__ == "__main__":
    main()
