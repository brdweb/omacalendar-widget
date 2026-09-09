# Changelog

All notable changes to the OmaCalendar widget are recorded here. The project
follows Keep a Changelog and will use Semantic Versioning once public releases
begin.

## [Unreleased]

## [0.1.0-rc.4] - 2026-09-09

### Fixed

- Use Omarchy 4.0.3's public bar API to suppress hover reveal while the popup
  is open. Its exposed state is read-only; direct assignment raised an error
  during popup opening and closing. Preserve compatibility with older hosts.
- Exercise the read-only host property and setter in the layout regression.

### Changed

- Prepare a new signed candidate for app RC4 qualification, preserving RC3
  tags, archives and historical evidence. Stable acceptance remains pending.

## [0.1.0-rc.3] - 2026-09-08

### Changed

- Target OmaCalendar `1.0.0-rc.3` after RC2 app verification found a Flatpak
  bundle/SPDX locale mismatch and a GitHub-normalized Debian filename.
- Rebuild the independently signed widget candidate and update exact download,
  installation, and owner acceptance guides. All manual gates remain pending;
  widget QML/JavaScript runtime is unchanged and needs no matching bug fix.
- Preserve RC1/RC2 signed tags and historical draft assets. Prior verification
  is not renamed or carried forward as acceptance of the new RC3 artifacts.

## [0.1.0-rc.2] - 2026-09-08

### Changed

- Prepare the replacement draft candidate with OmaCalendar `1.0.0-rc.2` and
  update the exact download, installation, verification, and acceptance guides.
- Supersede RC1 after GitHub rejected its tagger email as `unverified_email`,
  despite its valid local SSH signature. No widget release artifacts were
  published from RC1; its existing signed tag is preserved unchanged.
- Require the GitHub-verified release-owner tagger identity for the new signed
  RC2 tag. All manual stable acceptance gates remain pending; widget runtime
  QML/JavaScript is unchanged.

### Fixed

- Complete the source SPDX inventory with the exact widget identity/version,
  real shipped-file SHA-1/SHA-256 hashes, and explicit external-runtime scope.
  Reject missing source files, manifest mismatches, and invalid graph links.

## [0.1.0-rc.1] - 2026-09-08

Superseded before release artifacts were published because GitHub tagger-email
verification failed. The signed RC1 tag remains immutable; use RC2 for testing.

### Added

- Draft candidate downloads and a complete owner test, evidence, and rollback
  guide for qualification with OmaCalendar `1.0.0-rc.1`.
- A stable publication gate that requires every acceptance item to pass with
  evidence and owner sign-off; runtime changes invalidate earlier acceptance.
- Separate signed-app contract verification for RC draft preparation while
  published stable qualification still requires a published app release.
- Checksummed and attested test instructions and an acceptance-record template
  attached alongside the deterministic widget source archive.

### Changed

- Reconciled the historical beta acceptance record with the now-approved
  marketplace listing and documented the README-only `main` change after beta.
- Stable promotion and marketplace snapshot updates remain pending owner
  testing; the runtime QML/JavaScript is unchanged from the public beta.

## [0.1.0-beta.1] - 2026-09-06

### Added

- Beta acceptance record covering real Omarchy compositor, daemon, install,
  upgrade, removal, and privacy-safe preview verification.
- A ready-to-submit Omarchy Plugins marketplace issue body with the canonical
  category, tags, dependency note, and owner checklist.

### Changed

- Bound public Git installs to a release-only default branch and documented the
  attested signed-release archive as the immutable installation path because
  current Omarchy plugin add/update commands cannot select a tag or commit.
- Qualify the widget beta against OmaCalendar `1.0.0-beta.1` and install the app
  from its checksummed, attested native Arch package.
- Advanced the independent widget release metadata to `0.1.0-beta.1` and
  recorded the published OmaCalendar `1.0.0-beta.1` as its IPC 2 qualification
  target without coupling the projects' versions or release dates.
- Updated installation, alpha-to-beta upgrade, removal, compatibility, release,
  and current marketplace documentation.
- Added exact get, build, test, install, and socket-activation steps for the
  qualified desktop app, including its current Google OAuth verification status.
- Made a real root marketplace preview a release gate; mockups and screenshots
  containing private calendar data are not accepted.

### Fixed

- Send operation retry IDs as JSON numbers so the widget matches the app's IPC 2
  contract instead of silently issuing a string-valued request.
- Render every daemon-supplied calendar and event string as literal text so
  provider-controlled markup cannot alter the widget presentation.

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

[Unreleased]: https://github.com/brdweb/omacalendar-widget/compare/v0.1.0-rc.3...HEAD
[0.1.0-rc.3]: https://github.com/brdweb/omacalendar-widget/compare/v0.1.0-rc.2...v0.1.0-rc.3
[0.1.0-rc.2]: https://github.com/brdweb/omacalendar-widget/compare/v0.1.0-rc.1...v0.1.0-rc.2
[0.1.0-rc.1]: https://github.com/brdweb/omacalendar-widget/compare/v0.1.0-beta.1...v0.1.0-rc.1
[0.1.0-beta.1]: https://github.com/brdweb/omacalendar-widget/compare/v0.1.0-alpha...v0.1.0-beta.1
[0.1.0-alpha]: https://github.com/brdweb/omacalendar-widget/releases/tag/v0.1.0-alpha
