# Release validation

The maintainer approved stable publication of 0.1.3 on 2026-09-22 after this
exact fix ran live against the maintainer's own OmaCalendar daemon and real
calendar data on a current Omarchy laptop, confirming the previously blanked
snapshot and missing calendar day now resolve correctly. Automated coverage
includes IPC reconnect, offline cache, mutations, keyboard actions, agenda
positioning, default calendar, read-only details, and layout at 100%, 125%
and 200% scale, plus new regression fixtures for this fix. Install, upgrade,
remove, and transactional-restore paths are unchanged from 0.1.2 and were not
re-exercised, since this release touches only calendar data-model logic.

The signed source archive is checksum-verified and attested with provenance and
an SPDX file inventory. The release record distinguishes automated evidence
from maintainer acceptance. It does not certify every display/provider setup.

Use the README for installation, upgrade and removal. Preserve a prior plugin
snapshot when upgrading. Calendar credentials remain owned by the app daemon.
