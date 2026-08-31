# Widget 0.1.0-beta.1 acceptance

This record separates checks that can run in automation from the real Omarchy
and release-owner checks required before tagging `v0.1.0-beta.1`. Check an item
only when it was exercised against the candidate commit. Record failures as
issues and rerun affected checks after the fix.

## Candidate

- Widget: `0.1.0-beta.1`
- OmaCalendar app used for compatibility qualification: `1.0.0-alpha`
- IPC: major 2, minimum minor 0
- Release-reference system: Omarchy 4.0.2-1, Quickshell 0.3.1
- Candidate commit: _record the accepted 40-character SHA_
- Acceptance date: _YYYY-MM-DD_

## Automated gates

- [ ] `omarchy plugin validate .` passes on the candidate checkout.
- [ ] `./tests/run.sh` passes on the candidate checkout.
- [ ] GitHub CI and secret scanning pass on the candidate commit.
- [ ] `release.json`, `manifest.json`, changelog, and compatibility metadata agree.
- [ ] Signed app tag `v1.0.0-alpha` exists and exposes the recorded IPC major.
- [ ] Signed widget tag verification, deterministic archive, checksums, SBOM,
      and attestations pass from a clean checkout.

## Install, upgrade, and removal

- [ ] A fresh `omarchy plugin add … --enable` install succeeds and appears once
      in the configured bar section.
- [ ] Updating an installed `0.1.0-alpha` checkout preserves placement and widget
      settings and loads `0.1.0-beta.1`.
- [ ] `omarchy plugin remove org.omacalendar.widget` removes only the plugin and
      leaves the OmaCalendar app, daemon, data, and credentials intact.
- [ ] The transactional `omacalendar-widgetctl restore` path restores the exact
      prior clock, anchor, and shortcut configuration.

## Real Omarchy behavior

- [ ] Month, Day, Week, and Agenda open and remain usable at every bar edge.
- [ ] The popup is keyboard-drivable, Today re-centers Agenda, search clears and
      closes, and the footer remains visible at minimum supported height.
- [ ] Event create, edit, move, delete, and undo work while the desktop UI is
      closed; the default writable calendar is honored.
- [ ] The widget remains responsive through daemon start, restart, provider
      offline/reconnect, and a missed-revision full refresh.
- [ ] Accounts closes the popup and focuses the existing desktop window without
      opening a duplicate process.
- [ ] Theme hot reload and 100%, 125%, and 200% mixed-scale monitor moves preserve
      readable layout and correct anchoring.

## Public artifacts and marketplace readiness

- [ ] Root `preview.png` is a real widget capture using synthetic events and
      contains no personal calendar, account, notification, or desktop data.
- [ ] The public beta release and its checksums, SBOM, and attestations have been
      downloaded and independently verified.
- [ ] `org.omacalendar.widget` and the repository are absent from the live
      marketplace registry and existing submission issues.
- [ ] The owner has reviewed the exact `[Plugin]: OmaCalendar` title and
      [`MARKETPLACE_SUBMISSION.md`](MARKETPLACE_SUBMISSION.md), including rights
      to the repository and preview asset.
