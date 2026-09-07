#!/usr/bin/env python3
"""Verify the exact Omarchy host renders every widget-bound string literally."""

from __future__ import annotations

import os
import re
import unittest
from pathlib import Path


OMARCHY_ROOT = Path(os.environ.get("OMARCHY_PATH", "/usr/share/omarchy"))


def qml_object_bodies(source: str, type_name: str) -> list[str]:
    bodies: list[str] = []
    declaration = re.compile(rf"(?m)^\s*{re.escape(type_name)}\s*\{{")
    for match in declaration.finditer(source):
        start = source.index("{", match.start())
        depth = 0
        quote = ""
        escaped = False
        line_comment = False
        block_comment = False
        index = start
        while index < len(source):
            char = source[index]
            following = source[index + 1] if index + 1 < len(source) else ""
            if line_comment:
                if char == "\n":
                    line_comment = False
            elif block_comment:
                if char == "*" and following == "/":
                    block_comment = False
                    index += 1
            elif quote:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == quote:
                    quote = ""
            elif char == "/" and following == "/":
                line_comment = True
                index += 1
            elif char == "/" and following == "*":
                block_comment = True
                index += 1
            elif char in ('"', "'"):
                quote = char
            elif char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
                if depth == 0:
                    bodies.append(source[start + 1 : index])
                    break
            index += 1
        else:
            raise AssertionError(f"unterminated {type_name} object")
    return bodies


class OmarchyUiContractTest(unittest.TestCase):
    def test_widget_bound_host_text_surfaces_are_plain_text(self) -> None:
        ui_root = OMARCHY_ROOT / "shell" / "Ui"
        files = (
            ui_root / "Button.qml",
            ui_root / "WidgetButton.qml",
            ui_root / "OpticalGlyph.qml",
            ui_root / "PanelToolTip.qml",
            OMARCHY_ROOT / "shell" / "plugins" / "bar" / "Bar.qml",
        )
        checked = 0
        for path in files:
            self.assertTrue(path.is_file(), f"missing qualified Omarchy host surface: {path}")
            for body in qml_object_bodies(path.read_text(encoding="utf-8"), "Text"):
                if not re.search(r"(?m)^\s*text:\s*root\.(?:text|tooltipText)\s*$", body):
                    continue
                checked += 1
                self.assertRegex(
                    body,
                    r"(?m)^\s*textFormat:\s*Text\.PlainText\s*$",
                    f"{path} renders a widget-bound string without Text.PlainText",
                )
        # Button label + tooltip, WidgetButton label, and bar tooltip.
        self.assertGreaterEqual(checked, 4)


if __name__ == "__main__":
    unittest.main()
