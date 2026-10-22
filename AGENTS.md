# OmaCalendar Widget

QML/JavaScript Quickshell plugin for the Omarchy bar. Connects to `omacalendard` via Unix socket IPC. Current release: v0.2.0 (2026-09-30). Remote: https://github.com/brdweb/omacalendar-widget.git

## Architecture

The widget is a pure presentation client. All calendar data comes from the OmaCalendar daemon via IPC protocol. The widget has no database access, no credentials, and no direct provider networking. Tests use a fake daemon with synthetic events.

## Key files

- `BarWidget.qml` — bar entry point (`manifest.json` `entryPoints.barWidget`)
- `Panel.qml` — popup panel
- `OmaCalendarClient.qml` — IPC socket client
- `components/` — calendar views
- `tests/run.sh` — full suite: QML lint, fake-daemon IPC, keyboard, layout
- `tests/run-portable.sh` — portable subset (no display required)
- `tests/fake_daemon.py` — fake daemon with synthetic event data

## Build and verify

```bash
./tests/run-portable.sh   # QML lint, IPC protocol, keyboard — no display needed
./tests/run.sh            # full suite — requires a display
```

## Cursor Cloud specific instructions

The Cloud Agent install provides Qt 6.8.3 at `/usr/lib/qt6/bin`, Quickshell 0.3.2, Weston 16.0.1 (`--fake-seat`), and Tesseract 5.5.3 with the current English traineddata. The Omarchy shell reference pinned in `.github/workflows/ci.yml` is at `/usr/share/omarchy`, and `omarchy` is on `PATH`.

- `./tests/run-portable.sh` needs no display.
- `./tests/run-headless-omarchy.sh` is the full suite. It starts headless Weston itself. `./tests/run.sh` expects `WAYLAND_DISPLAY` to already exist.
- Preview OCR uses that Tesseract 5.5.3 install. The allowlist in `tools/preview/validate_preview.py` matches its reading of `preview.png`.

## Safety rules

- Never connect to the live daemon socket during automated work. Tests use only `tests/fake_daemon.py`.
- Do not access real calendar credentials, provider APIs, or the OmaCalendar SQLite database.
- Install/uninstall operations change the Omarchy shell layout; only perform them during an explicit release qualification.
