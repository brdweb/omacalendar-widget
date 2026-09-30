# Release validation

The maintainer directed stable publication of 0.2.0 on 2026-09-30. The live
checks below were run by Claude Code on the maintainer's current Omarchy
laptop, against the maintainer's own OmaCalendar 2.0.0 daemon and calendar
data, using the exact evidence-commit runtime installed through
omacalendar-widgetctl.

0.2.0 adds a Tasks view for OmaCalendar 2.0 (IPC 2.2) and fixes a reconnect
defect: with Quickshell 0.3.1 a widget that started before the daemon's socket
was listening never connected. Live, the Tasks view listed, added and completed
synthetic tasks in the device-only list only; no provider task list or event
was changed. Automated coverage includes IPC reconnect, late start, offline
cache, mutations, task paging and subscriptions, an IPC 2.1 daemon without
tasks, keyboard actions, agenda positioning, default calendar, read-only
details, the Tasks panel, and layout at 100%, 125% and 200% scale.

Upgrading a running shell may keep the previous widget until the shell restarts
(`omarchy restart shell`). A fresh install and removal from the packaged
archive, the desktop handoff, event mutations against real data and the late
start fix were not exercised live this cycle; see stable-acceptance.json for
exactly what each gate covered.

The signed source archive is checksum-verified and attested with provenance and
an SPDX file inventory. The release record distinguishes automated evidence
from maintainer acceptance. It does not certify every display/provider setup.

Use the README for installation, upgrade and removal. Preserve a prior plugin
snapshot when upgrading. Calendar credentials remain owned by the app daemon.
