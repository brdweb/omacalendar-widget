# Changelog

All notable changes to the OmaCalendar widget are recorded here. The project
follows Keep a Changelog and will use Semantic Versioning once public releases
begin.

## [Unreleased]

## [0.1.0-alpha] - 2026-08-30

### Added

- Concise installation, update, removal, dependency, and Omarchy marketplace
  submission documentation.
- Thin IPC 2 client for the OmaCalendar daemon with bar, month, agenda, search,
  and compact event-management surfaces.
- On-demand daemon integration so cached calendar data remains available while
  the desktop application is closed.
- Month, Day, Week, and Agenda popup views, including scrollable time grids and
  side-by-side overlap layout in Day and Week.
- Keyboard navigation, four-edge layout support, theme integration, cached
  offline presentation, revision recovery, and protocol mismatch handling.
- Portable, current-Omarchy, IPC fixture, scale, release, and secret-scanning
  validation.
- Deterministic source archives, SHA-256 manifests, SPDX SBOMs, and GitHub
  provenance/SBOM attestations for future signed release tags.

### Changed

- Calendar choices in the compact event editor now exclude read-only calendars.
- Removed sync, authorization, conflict, and operation-error indicators from
  the widget; diagnostics remain in the desktop application.
- The All Calendars control now expands into a local view filter containing
  All Calendars plus writable calendars only.

### Fixed

- Agenda events are now sorted by day and time instead of presenting the
  daemon's all-day-first storage order as the visible agenda order.
- Agenda now loads a rolling timeline before and after today, opens with today
  at the top, labels each row with its date, and supports scrolling both backward
  and forward through the loaded range.
- Today, Search, and Accounts now remain pinned below the scrolling calendar
  content in every view and panel size.
- Clicking Today in Agenda now re-centers the timeline even when Today was
  already selected and the list had been manually scrolled.
- Desktop handoffs now close the widget before launching OmaCalendar through
  the Omarchy session, allowing the requested app window to take focus.
- Month view sizing now accounts for the panel border and padding so the sixth
  calendar week remains visible above the pinned footer on first open.
- New events now select the writable default calendar supplied by the daemon,
  matching the desktop application.

- Authoritative `sync.statusChanged` notifications now bypass database-revision
  conditionals so syncing, authentication, and offline state refresh promptly.
- Standard edit shortcuts bind every platform sequence without emitting
  ambiguous `Shortcut` warnings in the live Omarchy shell.
- Removed the lower-right invitation/reminder detail surface and added explicit
  Clear and Close actions to search.
- Kept inline event creation and editing while removing invitation and reminder
  controls from the compact detail area.

[Unreleased]: https://github.com/brdweb/omacalendar-widget/compare/v0.1.0-alpha...HEAD
[0.1.0-alpha]: https://github.com/brdweb/omacalendar-widget/releases/tag/v0.1.0-alpha
