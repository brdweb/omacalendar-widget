#!/usr/bin/env python3
"""Portable structural checks for the thin Omarchy widget contract."""

from __future__ import annotations

import ast
import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def text(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class StaticContractTest(unittest.TestCase):
    def test_manifest_identity_and_compatibility(self) -> None:
        manifest = json.loads(text("manifest.json"))
        self.assertEqual(manifest["id"], "org.omacalendar.widget")
        self.assertEqual(manifest["version"], "0.1.0-alpha")
        self.assertEqual(manifest["entryPoints"]["barWidget"], "BarWidget.qml")
        self.assertEqual(manifest["compatibility"]["omacalendarProtocolMajor"], 2)
        self.assertEqual(manifest["compatibility"]["minimumOmaCalendarProtocolMinor"], 0)
        self.assertEqual(manifest["compatibility"]["minimumOmarchy"], "4.0.0")
        release = json.loads(text("release.json"))
        self.assertEqual(release["widgetVersion"], manifest["version"])
        self.assertEqual(release["testedOmaCalendarVersion"], "1.0.0-alpha")
        self.assertEqual(release["omacalendarProtocolMajor"], 2)

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
        self.assertIn('root.broadcast("refresh")', bar)
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
            'omacalendar/git/ref/tags/v${app_version}',
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
