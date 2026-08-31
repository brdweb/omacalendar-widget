# Compatibility matrix

The app and widget have independent release versions. Every widget candidate
records the exact OmaCalendar version used for qualification. IPC major
mismatches are rejected; optional minor additions are discovered from the
daemon's advertised method list.

| Widget version | OmaCalendar app version | IPC major | Status |
|---|---|---:|---|
| `0.1.0-alpha` | `1.0.0-alpha` | 2 | Alpha test pair; owner acceptance pending |

The current manifest requires Omarchy 4.0.0 or newer, Quickshell 0.3.1 or newer,
and OmaCalendar IPC 2.0 or newer. The alpha was qualified locally with Omarchy
4.0.1-1 and Quickshell 0.3.1. Before tagging another release, update the exact
app/widget row and `release.json`, then record the Omarchy and Quickshell
versions used for acceptance.

The qualified app package must install and enable `omacalendard.socket`; the
widget uses that on-demand endpoint and does not require the desktop UI process.
