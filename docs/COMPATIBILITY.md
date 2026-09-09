# Compatibility matrix

The app and widget have independent release versions. Every widget candidate
records the exact OmaCalendar version used for qualification. IPC major
mismatches are rejected; optional minor additions are discovered from the
daemon's advertised method list.

| Widget version | OmaCalendar app version | IPC major | Status |
|---|---|---:|---|
| `0.1.0-alpha` | `1.0.0-alpha` | 2 | Alpha compatibility record; owner acceptance pending |
| `0.1.0-beta.1` | `1.0.0-beta.1` | 2 | Beta widget qualification against the published IPC 2 runtime; acceptance pending |
| `0.1.0-rc.1` | `1.0.0-rc.1` | 2 | Superseded before release artifacts: GitHub tagger-email verification failed; tag retained unchanged |
| `0.1.0-rc.2` | `1.0.0-rc.2` | 2 | Current draft candidate qualification target; package and manual runtime acceptance pending |

The current manifest requires Omarchy 4.0.0 or newer, Quickshell 0.3.1 or newer,
and OmaCalendar IPC 2.0 or newer. The beta metadata and automated suite were
validated locally with Omarchy 4.0.2-1 and Quickshell 0.3.1; the real compositor,
provider-offline, and mixed-scale acceptance items remain recorded in
[`BETA_ACCEPTANCE.md`](BETA_ACCEPTANCE.md). Before tagging another release,
update the exact app/widget row and `release.json`, then record the Omarchy and
Quickshell versions used for acceptance.

The RC test pass and stable gates are in
[`STABLE_ACCEPTANCE.md`](STABLE_ACCEPTANCE.md). Candidate automation checks the
app's signed tag and IPC constants; only the completed acceptance record can
establish that the two candidate artifacts were actually exercised together.

The qualified app package must install and enable `omacalendard.socket`; the
widget uses that on-demand endpoint and does not require the desktop UI process.
