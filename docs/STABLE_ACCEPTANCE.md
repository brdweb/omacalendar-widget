# Release validation

Widget 1.0.0 targets OmaCalendar 2.1.0 / IPC 2.3. This is a prepared candidate,
not a published or owner-accepted release. Historical 0.2.0 acceptance remains
in Git history and does not approve the changed runtime.

Run `tests/run-portable.sh` and `tests/run.sh` against synthetic fixture data.
Record the tested commit and evidence in `stable-acceptance.json`. Repeat
install/upgrade/remove, restore, views, keyboard, mutations, resilience,
desktop handoff and theme/scale acceptance before marking the gates passed.
Never use the live daemon during automated testing.

After owner acceptance, the maintainer signs the immutable tag. Verify the
release archive checksums, provenance and SPDX attestations before publication.
Promote the release-only install branch only to that verified commit.

The app installer update follows the signed widget tag: update both pins in
`src/app/appcontroller.cpp` and `scripts/omacalendar-widgetctl`, their contract
tests, compatibility docs and changelog to v1.0.0 and its exact commit.
Do not invent a commit or change the installer to an unpublished target.

## Candidate validation (2026-11-15)

- Portable suite passes, including 27 model tests, release contracts and syntax.
- Signed published app contract verified: v2.1.0, commit
  `48edffff66ca72b4d8058cbb9a9009e701d0cc45`, IPC 2.3.
- Full suite passes IPC scenarios, keyboard, agenda, default calendar,
  read-only details, Tasks panel and layout at 100%, 125% and 200%.
- Exact merged runtime: `26972c11e75e7cdadccca898fe72c976c627a0f2`.
  Reference integration CI run `43796164057` and Gitleaks passed.
  A separate local reference-container attempt failed during dependency
  provisioning before the suite ran; the installed-Omarchy suite passed.
- Resolved: short logical screens use compact calendar rows. Layout probes
  pass at 100%, 125% and 200%; the original 200% regression failed before the fix.
- Resolved: explicit Omarchy Color imports restore theme colours. The new
  synthetic screenshot passes metadata and strict OCR privacy validation.
  The reviewed OCR spelling agends maps only to the visible Agenda label.
- Capture harness now tolerates the current Omarchy Color API without the
  removed loadShell function. Screenshot qualification now passes.

Desktop-only features remain desktop-only: full reminder editing, colour
editing, copy/cut/paste, hidden weekends/declined events and custom week length.
The widget continues to offer More options in app for advanced editing.
