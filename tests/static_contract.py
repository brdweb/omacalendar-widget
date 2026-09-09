#!/usr/bin/env python3
"""Portable structural checks for the thin Omarchy widget contract."""

from __future__ import annotations

import ast
import json
import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def text(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def qml_object_bodies(source: str, type_name: str) -> list[str]:
    """Return complete bodies for line-leading QML object declarations."""
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


def fenced_bash_after(source: str, heading_or_phrase: str) -> str:
    section = source.index(heading_or_phrase)
    fence = source.index("```bash\n", section) + len("```bash\n")
    return source[fence : source.index("\n```", fence)]


class StaticContractTest(unittest.TestCase):
    def test_qml_text_surfaces_render_provider_content_literally(self) -> None:
        production_qml = sorted(ROOT.glob("*.qml")) + sorted(
            (ROOT / "components").glob("*.qml")
        )
        checked = 0
        for path in production_qml:
            for body in qml_object_bodies(path.read_text(encoding="utf-8"), "Text"):
                checked += 1
                self.assertRegex(
                    body,
                    r"(?m)^\s*textFormat:\s*Text\.PlainText\s*$",
                    f"{path.relative_to(ROOT)} has a Text object without literal rendering",
                )
        self.assertGreater(checked, 0)

    def test_provider_text_host_control_bindings_are_explicit(self) -> None:
        # These provider-derived bindings are intentionally rendered by Omarchy
        # host controls. tests/omarchy_ui_contract.py verifies the actual host
        # implementation used by the full native/current-Arch suites.
        bindings = {
            "BarWidget.qml": (
                'text: root.vertical ? "" : root.horizontalText',
                "tooltipText: root.upNext",
            ),
            "Panel.qml": (
                "text: root.selectedCalendarName +",
                'text: String(modelData.name || "Calendar")',
            ),
            "components/EventEditor.qml": (
                'text: root.selectedCalendar ? "Calendar · " + String(root.selectedCalendar.name || "Calendar")',
            ),
        }
        for path, expected in bindings.items():
            source = text(path)
            for binding in expected:
                self.assertIn(binding, source)

    def test_manifest_identity_and_compatibility(self) -> None:
        manifest = json.loads(text("manifest.json"))
        self.assertEqual(manifest["id"], "org.omacalendar.widget")
        self.assertEqual(manifest["version"], "0.1.0-rc.3")
        self.assertEqual(manifest["entryPoints"]["barWidget"], "BarWidget.qml")
        self.assertEqual(manifest["compatibility"]["omacalendarProtocolMajor"], 2)
        self.assertEqual(manifest["compatibility"]["minimumOmaCalendarProtocolMinor"], 0)
        self.assertEqual(manifest["compatibility"]["minimumOmarchy"], "4.0.0")
        release = json.loads(text("release.json"))
        self.assertEqual(release["widgetVersion"], manifest["version"])
        self.assertEqual(release["testedOmaCalendarVersion"], "1.0.0-rc.3")
        self.assertEqual(release["omacalendarProtocolMajor"], 2)
        self.assertEqual(release["minimumOmaCalendarProtocolMinor"], 0)
        self.assertEqual(release["releaseChannel"], "rc")
        self.assertEqual(release["trustedInstallBranch"], "main")
        self.assertEqual(
            release["trustedInstallTag"], f'v{release["widgetVersion"]}'
        )
        acceptance = json.loads(text("docs/stable-acceptance.json"))
        self.assertEqual(acceptance["candidateVersion"], manifest["version"])
        self.assertEqual(
            acceptance["candidateOmaCalendarVersion"], release["testedOmaCalendarVersion"]
        )
        self.assertIn(f'## [{manifest["version"]}] - ', text("CHANGELOG.md"))
        self.assertIn(
            f'| `{manifest["version"]}` | `{release["testedOmaCalendarVersion"]}` | 2 |',
            text("docs/COMPATIBILITY.md"),
        )

    def test_public_install_sources_are_release_bound(self) -> None:
        readme = text("README.md")
        marketplace = text("docs/MARKETPLACE.md")
        submission = text("docs/MARKETPLACE_SUBMISSION.md")
        release_guide = text("docs/RELEASE.md")

        self.assertIn("Install a verified release archive", readme)
        self.assertIn("release_version=0.1.0-beta.1", readme)
        self.assertIn('archive="omacalendar-widget-${release_version}-source.tar.gz"', readme)
        self.assertIn("gh attestation verify", readme)
        self.assertIn('--source-ref "refs/tags/v${release_version}"', readme)
        self.assertIn("--signer-workflow brdweb/omacalendar-widget/.github/workflows/release.yml", readme)
        self.assertIn("release-only `main`", readme)
        self.assertIn("fetches and fast-forwards", readme)
        self.assertIn("`origin HEAD`", readme)
        self.assertIn("release-only `main`", marketplace)
        self.assertIn("exact commit of signed tag `v0.1.0-beta.1`", submission)
        self.assertIn("git ls-remote --symref origin HEAD", release_guide)
        self.assertIn('refs/tags/${release_tag}^{}', release_guide)
        self.assertIn("release-only install", text("SECURITY.md"))

    def test_app_install_recipes_stop_before_privilege_after_failed_verification(self) -> None:
        recipes = (
            fenced_bash_after(text("README.md"), "## Install the required OmaCalendar app"),
            fenced_bash_after(text("docs/MARKETPLACE_SUBMISSION.md"), "Install the qualified app's"),
        )
        for recipe in recipes:
            self.assertEqual(recipe.splitlines()[0], "set -euo pipefail")
            self.assertIn(
                "--signer-workflow brdweb/omacalendar/.github/workflows/release.yml",
                recipe,
            )
            self.assertLess(recipe.index("sha256sum --check"), recipe.index("sudo pacman"))
            self.assertLess(recipe.index("gh attestation verify"), recipe.index("sudo pacman"))

            for failed_command in ("sha256sum", "gh"):
                with self.subTest(failed_command=failed_command), tempfile.TemporaryDirectory() as tmp:
                    tmp_path = Path(tmp)
                    bin_path = tmp_path / "bin"
                    bin_path.mkdir()
                    marker = tmp_path / "privileged-command-ran"
                    scripts = {
                        "curl": '#!/bin/sh\nfor arg; do :; done\ntouch "${arg##*/}"\n',
                        "grep": "#!/bin/sh\nprintf 'fixture  package\\n'\n",
                        "sha256sum": "#!/bin/sh\ncat >/dev/null\nexit "
                        + ("1\n" if failed_command == "sha256sum" else "0\n"),
                        "gh": "#!/bin/sh\nexit " + ("1\n" if failed_command == "gh" else "0\n"),
                        "sudo": f'#!/bin/sh\ntouch "{marker}"\nexit 0\n',
                        "systemctl": f'#!/bin/sh\ntouch "{marker}"\nexit 0\n',
                    }
                    for name, contents in scripts.items():
                        executable = bin_path / name
                        executable.write_text(contents, encoding="utf-8")
                        executable.chmod(0o755)
                    result = subprocess.run(
                        ["bash", "-c", recipe],
                        cwd=tmp_path,
                        env={**os.environ, "PATH": f"{bin_path}:/usr/bin:/bin"},
                        check=False,
                        capture_output=True,
                        text=True,
                    )
                    self.assertNotEqual(result.returncode, 0)
                    self.assertFalse(marker.exists(), result.stdout + result.stderr)

    def test_marketplace_submission_is_ready_but_preview_remains_real(self) -> None:
        submission = text("docs/MARKETPLACE_SUBMISSION.md")
        headings = (
            "### Repository URL",
            "### Category",
            "### Tags",
            "### Suggest a missing tag",
            "### Maintainer notes",
            "### Submission checklist",
        )
        positions = [submission.index(heading) for heading in headings]
        self.assertEqual(positions, sorted(positions))
        self.assertIn("https://github.com/brdweb/omacalendar-widget", submission)
        self.assertIn("\nWidgets\n", submission)
        self.assertIn("\nbar, quickshell\n", submission)
        official_checklist = (
            "The repository is public and contains installation and removal instructions.",
            "I have documented the plugin license and any external dependencies.",
            "I confirm that I own or have permission to submit this plugin and its preview assets.",
            "The plugin does not overwrite user configuration without explicit consent.",
            "I understand that approval is for listing and is not a security review.",
        )
        for statement in official_checklist:
            self.assertIn(f"- [x] {statement}", submission)

        marketplace = text("docs/MARKETPLACE.md")
        self.assertIn("omacom/omarchy-plugin-marketplace", marketplace)
        self.assertIn('--title "[Plugin]: OmaCalendar"', marketplace)
        self.assertIn("--body-file docs/MARKETPLACE_SUBMISSION.md", marketplace)

        release_verifier = text("scripts/release/verify-release.sh")
        self.assertIn("release requires exactly one real root marketplace preview image", release_verifier)
        self.assertIn("tools/preview/validate_preview.py", release_verifier)
        self.assertIn("VALIDATOR.inspect_ocr(preview_path)", text("tests/preview_contract.py"))
        self.assertIn("synthetic events", text("docs/BETA_ACCEPTANCE.md"))

    def test_widget_remains_a_local_presentation_client(self) -> None:
        sources = "\n".join(
            path.read_text(encoding="utf-8")
            for path in sorted(ROOT.rglob("*.qml")) + sorted(ROOT.rglob("*.js"))
            if ".git" not in path.parts
        )
        forbidden_apis = (
            r"\bXMLHttpRequest\b",
            r"\bQtNetwork\b",
            r"\bLocalStorage\b",
            r"\bFileView\b",
            r"\bSecretService\b",
            r"\bQSqlDatabase\b",
            r"\bsqlite3?\b",
        )
        for pattern in forbidden_apis:
            self.assertIsNone(re.search(pattern, sources, re.IGNORECASE), pattern)

        client = text("OmaCalendarClient.qml")
        self.assertIn('runtime + "/omacalendar/daemon.sock"', client)
        self.assertIn("Socket {", client)
        self.assertNotIn("Process {", client)

        launch_lines = [line.strip() for line in sources.splitlines() if "execDetached" in line]
        self.assertTrue(launch_lines)
        self.assertTrue(all('"xdg-open"' in line for line in launch_lines))

    def test_host_primitives_cover_edges_monitors_scale_and_theme_reload(self) -> None:
        bar = text("BarWidget.qml")
        panel = text("Panel.qml")

        # Omarchy's current KeyboardPanel derives the output from anchorItem,
        # positions from bar.position (top/bottom/left/right), creates dismissal
        # surfaces for peer outputs, and consumes live Color/Style singletons.
        for needle in (
            "KeyboardPanel {",
            "anchorItem: root.anchorItem",
            "owner: root.barIdentity",
            "bar: root.bar",
            "centerOnBar: true",
            "panel.fittedContentWidth",
            "panel.fittedContentHeight",
        ):
            self.assertIn(needle, panel)
        # Current Omarchy routes summon/hide/toggle through the focused
        # monitor's BarWidget instance. A plugin-local IpcHandler would be
        # instantiated once per monitor and collide on the same target.
        self.assertNotIn("IpcHandler {", bar)
        self.assertIn("function open()", bar)
        self.assertIn("function close()", bar)
        self.assertIn("function togglePanel()", bar)
        self.assertIn("root.vertical", bar)
        self.assertIn('root.privacy === "hidden"', bar)
        self.assertIn("Style.space", panel)
        self.assertIn("Color.", panel)
        self.assertIsNone(re.search(r"#[0-9a-fA-F]{3,8}\b", bar + panel))

    def test_keyboard_surface_has_navigation_and_core_actions(self) -> None:
        panel = text("Panel.qml")
        for needle in (
            "PanelKeyCatcher {",
            "onMoveRequested:",
            "onActivateRequested:",
            "onCloseRequested:",
            'sequences: ["Delete"]',
            'sequences: ["Ctrl+N"]',
            'sequences: ["Ctrl+F"]',
            'sequences: ["Ctrl+Z"]',
        ):
            self.assertIn(needle, panel)

    def test_popup_exposes_month_day_week_and_agenda_views(self) -> None:
        panel = text("Panel.qml")
        timeline = text("components/CompactTimeline.qml")
        for needle in (
            '{ id: "month", label: "Month" }',
            '{ id: "day", label: "Day" }',
            '{ id: "week", label: "Week" }',
            '{ id: "agenda", label: "Agenda" }',
            "Components.CompactTimeline",
            "Components.EventEditor",
        ):
            self.assertIn(needle, panel)
        self.assertIn("eventWidth: availableWidth / Math.max(1, modelData.columns)", timeline)

    def test_primary_footer_actions_stay_outside_the_scrolling_content(self) -> None:
        panel = text("Panel.qml")
        self.assertIn("panel.fittedContentHeight(", panel)
        self.assertIn("contentColumn.implicitHeight + footerRow.implicitHeight", panel)
        self.assertIn("readonly property real bodyViewportHeight", panel)
        self.assertIn("bodyContentHeight > topPanel.bodyViewportHeight", text("tests/layout_harness.qml"))
        scroll_start = panel.index("Flickable {\n        id: panelScroll")
        footer_start = panel.index("Row {\n        id: footerRow")
        self.assertGreater(footer_start, scroll_start)
        self.assertIn("anchors.bottom: footerSeparator.top", panel[scroll_start:footer_start])
        self.assertIn("anchors.bottom: parent.bottom", panel[footer_start:])
        scroll_content = panel[scroll_start:footer_start]
        self.assertNotIn('text: "Today"', scroll_content)
        self.assertNotIn('text: "Accounts"', scroll_content)

    def test_desktop_handoffs_close_the_widget_and_request_activation(self) -> None:
        panel = text("Panel.qml")
        client = text("OmaCalendarClient.qml")
        handoff = panel[panel.index("function openDesktop(path)") : panel.index("function respond(")]
        self.assertLess(handoff.index("root.close()"), handoff.index("daemonClient.openDeepLink(path)"))
        self.assertIn('root.openDesktop("settings/accounts")', panel)
        self.assertIn('["uwsm-app", "--", "xdg-open", "omacalendar://" + suffix]', client)

    def test_revision_recovery_protocol_guard_and_offline_cache_are_explicit(self) -> None:
        client = text("OmaCalendarClient.qml")
        for needle in (
            "protocolMajor: protocolMajor",
            'major !== protocolMajor || minor < minimumProtocolMinor',
            'connectionState !== "incompatible"',
            "incomingRevision > revision + 1",
            "forceNextSnapshot = true",
            "needsBaseline = true",
            "params.sinceRevision = revision",
            "Service unavailable; showing the last snapshot",
            "root._scheduleReconnect()",
        ):
            self.assertIn(needle, client)

        # Disconnect handling must retain the existing presentation DTO. Empty
        # snapshots are initialized once, never assigned during disconnect.
        disconnect = client[client.index("onConnectionStateChanged:") : client.index("Timer {", client.index("onConnectionStateChanged:"))]
        self.assertNotIn("root.snapshot = ({})", disconnect)
        self.assertNotIn("root.snapshot = {}", disconnect)

    def test_sync_status_notifications_bypass_database_revision_conditionals(self) -> None:
        client = text("OmaCalendarClient.qml")
        self.assertIn('event === "sync.statusChanged"', client)
        self.assertIn('event === "sync.changed"', client)
        sync_branch = client[
            client.index("if (syncStatusChanged)") : client.index("var incomingRevision")
        ]
        self.assertIn("forceNextSnapshot = true", sync_branch)
        self.assertIn("notificationRefresh.restart()", sync_branch)

        fixture = text("tests/fake_daemon.py")
        self.assertIn('self.scenario == "sync-status"', fixture)
        self.assertIn('"event": "sync.statusChanged"', fixture)
        self.assertIn('"sinceRevision" in params', fixture)

    def test_current_event_uses_daemon_global_snapshot_with_compatibility_fallback(self) -> None:
        panel = text("Panel.qml")
        self.assertIn("snapshot.currentEvent !== undefined", panel)
        self.assertIn("Model.currentEvent(allEvents, today)", panel)
        self.assertIn("Model.hasEvent(snapshot.currentEvent)", panel)
        self.assertIn("Model.hasEvent(snapshot.upNext)", panel)
        client = text("OmaCalendarClient.qml")
        self.assertIn("currentEvent: null", client)

    def test_recurring_mutations_use_the_daemon_wire_contract(self) -> None:
        client = text("OmaCalendarClient.qml")
        panel = text("Panel.qml")
        self.assertIn('if (value === "this" || value === "this_occurrence") return "occurrence"', client)
        self.assertIn("function _eventReference(event)", client)
        self.assertIn("reference.recurrenceId = recurrenceId", client)
        self.assertNotIn("eventRef: { eventId: String(event.id), occurrenceStart", client)
        self.assertIn("capabilities.thisAndFuture === true", panel)
        self.assertIn("if (!movingCalendars && futureScopeSupportedForEvent(candidate))", panel)
        self.assertNotIn('var values = ["this", "future", "series"]', panel)

    def test_editor_routes_same_account_calendar_changes_through_events_move(self) -> None:
        panel = text("Panel.qml")
        client = text("OmaCalendarClient.qml")
        editor = text("components/EventEditor.qml")
        self.assertIn("Components.EventEditor", panel)
        self.assertIn("? daemonClient.moveEvent : daemonClient.updateEvent", panel)
        self.assertIn('_mutation("events.move"', client)
        self.assertIn("confirmedCrossProvider: false", client)
        self.assertIn("Cross-account moves require confirmation in the desktop app", editor)

    def test_editor_only_offers_writable_calendars_and_widget_hides_diagnostics(self) -> None:
        editor = text("components/EventEditor.qml")
        panel = text("Panel.qml")
        bar = text("BarWidget.qml")
        self.assertIn("readonly property var writableCalendars", editor)
        self.assertIn("Model.writableCalendars(calendars)", editor)
        self.assertIn("readonly property var selectedCalendar: writableCalendars.length", editor)
        self.assertIn('property string defaultCalendarId: ""', editor)
        self.assertIn('event && event.calendarId || defaultCalendarId', editor)
        self.assertIn('root.snapshot.defaultCalendarId', panel)
        self.assertIn("enabled: root.writableCalendars.length > 0", editor)
        self.assertNotIn("Components.StatusBanner", panel)
        self.assertNotIn('text: "Conflicts "', panel)
        self.assertNotIn("serviceProblem", bar)
        self.assertNotIn("syncSummary", bar)
        self.assertNotIn("Calendar account needs authorization", bar)

    def test_calendar_selector_filters_locally_and_agenda_is_chronological(self) -> None:
        panel = text("Panel.qml")
        model = text("CalendarModel.js")
        agenda = text("components/AgendaList.qml")
        self.assertIn("property bool calendarSelectorOpen", panel)
        self.assertIn("Model.writableCalendars(calendars)", panel)
        self.assertIn("Model.eventsForCalendar(allEvents, selectedCalendarId)", panel)
        self.assertIn("Model.agendaTimelineEvents(source)", panel)
        self.assertIn("Model.agendaAnchorIndex(agendaViewEvents, selectedDate)", panel)
        self.assertIn("agendaAnchorRevision++", panel)
        self.assertIn("root.agendaAnchorRevision", panel)
        self.assertIn('rangeStart = Model.addDays(selectedDate, -60)', panel)
        self.assertIn('rangeEnd = Model.addDays(selectedDate, 180)', panel)
        self.assertIn('text: "All Calendars"', panel)
        self.assertIn('text === "c" || text === "C"', panel)
        self.assertIn("function eventsForCalendar", model)
        self.assertIn("function upcomingEvents", model)
        self.assertIn("function agendaTimelineEvents", model)
        self.assertIn("function agendaAnchorIndex", model)
        self.assertIn("function positionAtAnchor", agenda)
        self.assertIn("onMovementStarted: root.autoPositionEnabled = false", agenda)
        self.assertIn("ScrollBar.vertical", agenda)

    def test_bad_transport_data_forces_a_reconnectable_disconnect(self) -> None:
        client = text("OmaCalendarClient.qml")
        self.assertIn("transportFailureDetail", client)
        self.assertIn('socket.connected = false', client)

    def test_editor_rejects_normalized_dates_and_keeps_all_day_end_exclusive(self) -> None:
        editor = text("components/EventEditor.qml")
        self.assertIn("date.getFullYear() !== year || date.getMonth() !== month", editor)
        self.assertIn("Model.dateKey(exclusiveEnd) <= Model.dateKey(start)", editor)

    def test_python_fixtures_parse_without_writing_bytecode(self) -> None:
        for path in sorted((ROOT / "tests").glob("*.py")):
            ast.parse(path.read_text(encoding="utf-8"), filename=str(path))

    def test_release_pipeline_is_draft_only_independent_and_attested(self) -> None:
        workflow = text(".github/workflows/release.yml")
        for needle in (
            "needs: current-omarchy-gate",
            "scripts/release/verify-qualified-app.py",
            "./scripts/release/verify-release.sh",
            "./scripts/release/package-source.sh",
            "anchore/sbom-action@",
            "sha256sum --check SHA256SUMS",
            "actions/attest@",
            "--draft",
            "refusing to replace assets on an already published release",
        ):
            self.assertIn(needle, workflow)
        self.assertNotRegex(workflow, r"gh release create[^\n]*--latest")

        qualified_app_gate = text("scripts/release/verify-qualified-app.py")
        for needle in (
            'APP_REPOSITORY = "brdweb/omacalendar"',
            '/git/ref/tags/{tag}',
            '/git/tags/{tag_sha}',
            'verification.get("verified") is not True',
            '/releases/tags/{tag}',
            'release.get("draft") is not False',
            'contents/{DOMAIN_HEADER}?ref={commit_sha}',
            '"kIpcProtocolMajor"',
            '"kIpcProtocolMinor"',
        ):
            self.assertIn(needle, qualified_app_gate)

        package_script = text("scripts/release/package-source.sh")
        self.assertIn("gzip -n -9", package_script)
        self.assertIn("cmp -s", package_script)
        self.assertIn("git -C", package_script)
        self.assertIn("archive", package_script)

        release_verifier = text("scripts/release/verify-release.sh")
        self.assertIn("must carry a PGP or SSH signature", release_verifier)
        self.assertIn("org.omacalendar.widget", release_verifier)
        self.assertIn("clean checkout", release_verifier)
        self.assertIn("testedOmaCalendarVersion", release_verifier)
        self.assertIn("PRERELEASE", release_verifier)

    def test_secret_scan_uses_default_rules_without_credential_allowlists(self) -> None:
        workflow = text(".github/workflows/secret-scan.yml")
        config = text(".gitleaks.toml")
        self.assertIn("gitleaks/gitleaks-action@", workflow)
        self.assertIn("fetch-depth: 0", workflow)
        self.assertIn("useDefault = true", config)
        self.assertNotIn("allowlists", config)


if __name__ == "__main__":
    unittest.main(verbosity=2)
