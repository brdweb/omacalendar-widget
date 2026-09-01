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
- Acceptance date: In progress; pre-tag evidence updated 2026-09-01

## Automated gates

- [x] `omarchy plugin validate .` passes on the candidate checkout.
- [x] `./tests/run.sh` passes on the candidate checkout.
- [x] GitHub CI and secret scanning pass on the candidate runtime code.
- [x] `release.json`, `manifest.json`, changelog, and compatibility metadata agree.
- [x] App tag `v1.0.0-alpha` is annotated and GitHub-signature-verified, resolves
      to a commit, has a published non-draft release, and its tagged source
      exposes the recorded IPC major and minimum minor.
- [ ] Signed widget tag verification, deterministic archive, checksums, SBOM,
      and attestations pass from a clean checkout.

## Install, upgrade, and removal

- [ ] The checksummed release archive passes both provenance and SPDX
      attestation verification, plugin validation, and a fresh snapshot install.
- [ ] A fresh `omarchy plugin add … --enable` install from release-only `main`
      resolves to the exact signed `v0.1.0-beta.1` commit and appears once in the
      configured bar section.
- [ ] Updating an installed `0.1.0-alpha` checkout preserves placement and widget
      settings, fast-forwards only to release-only `main`, and loads
      `0.1.0-beta.1` from the signed tag commit.
- [x] `omarchy plugin remove org.omacalendar.widget` removes only the plugin and
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

- [x] Root `preview.png` is a real widget capture using synthetic events and
      contains no personal calendar, account, notification, or desktop data.
- [ ] The public beta release and its checksums, SBOM, and attestations have been
      downloaded and independently verified.
- [ ] Remote default `HEAD`, release-only `main`, and peeled signed tag
      `v0.1.0-beta.1^{}` resolve to the same accepted 40-character commit; force
      pushes and development commits are prohibited on `main`.
- [x] `org.omacalendar.widget` and the repository are absent from the live
      marketplace registry and existing submission issues.
- [ ] The owner has reviewed the exact `[Plugin]: OmaCalendar` title and
      [`MARKETPLACE_SUBMISSION.md`](MARKETPLACE_SUBMISSION.md), including rights
      to the repository and preview asset.

## Pre-tag evidence gathered on 2026-09-01

- Current Omarchy 4.0.2 passed the complete repository suite and native
  `omarchy plugin validate .`; pull request 2 passed both current-Omarchy jobs
  and both complete-history secret scans.
- The live Git installation added and enabled the permanent plugin ID, matched
  remote `main`, opened and closed through the shell's focused-widget route,
  disabled/re-enabled, and reported cleanly up to date.
- A duplicate per-monitor IPC registration found during that live pass was
  fixed in pull request 2. After a shell restart and Git-managed update, the
  OmaCalendar handler warning was absent and panel summon/hide still passed.
- A published `v0.1.0-alpha` checkout fast-forwarded through `omarchy plugin
  update` to `0.1.0-beta.1` while preserving the exact shell configuration and
  enabled placement.
- Removal deleted only the Git-managed plugin checkout. The separately
  installed OmaCalendar package, active daemon, data directory, and connected
  provider state remained intact; a fresh add/enable and panel lifecycle then
  passed again.
- Preview validation confirmed an 824x516 metadata-free image rendered from
  synthetic data with only allowlisted OCR labels. The exact plugin ID and
  repository were absent from the live marketplace registry and all existing
  submission issues.

These results do not close the unchecked real-compositor/hardware acceptance,
signed-tag, public-artifact, exact-tag/default-branch, or marketplace-owner
submission gates. Do not tag or submit while any of those rows remains open.
