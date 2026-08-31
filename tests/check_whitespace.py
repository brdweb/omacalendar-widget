#!/usr/bin/env python3
"""Reject trailing whitespace and missing final newlines in text files."""

from pathlib import Path


repository_root = Path(__file__).resolve().parents[1]
errors: list[str] = []

for path in sorted(repository_root.rglob("*")):
    if not path.is_file() or ".git" in path.parts:
        continue

    data = path.read_bytes()
    if b"\0" in data:
        continue

    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        continue

    relative_path = path.relative_to(repository_root)
    if text and not text.endswith("\n"):
        errors.append(f"{relative_path}: missing final newline")

    for line_number, line in enumerate(text.splitlines(), start=1):
        if line.endswith((" ", "\t")):
            errors.append(f"{relative_path}:{line_number}: trailing whitespace")

if errors:
    raise SystemExit("\n".join(errors))

print("Whitespace validation passed")
