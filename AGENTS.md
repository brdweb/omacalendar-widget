# AGENTS.md

Instructions for coding agents in this repository (Cursor cloud agents, Codex, Claude Code). The maintainer reviews and merges.

Personal or machine-specific notes never go in tracked files. Claude Code auto-loads the gitignored `CLAUDE.local.md`; Codex users put personal guidance in `~/.codex/AGENTS.md`; `AGENTS.local.md` is a gitignored scratch file that tools don't load automatically.

## Project

OmaCalendar widget (`org.omacalendar.widget`, v0.2.0, MIT) is a QML/JavaScript Quickshell plugin for the Omarchy bar. It is a pure presentation client. Calendar data comes from `omacalendard` as newline-delimited JSON on the user-local Unix socket (IPC major 2). The widget has no database access, no credentials, and no direct provider networking. It is qualified with OmaCalendar 2.0.0 over IPC 2.2 and still works with OmaCalendar 1.x (IPC 2.0 and 2.1) without the Tasks view. It needs Omarchy 4.0 or newer and Quickshell 0.3.1 or newer. Current release: v0.2.0 (2026-09-30).

- `BarWidget.qml` — bar entry point (`manifest.json` `entryPoints.barWidget`).
- `Panel.qml` — popup panel.
- `OmaCalendarClient.qml` — IPC socket client.
- `CalendarModel.js` — date and event model.
- `components/` — calendar views.
- `tests/fake_daemon.py` — fake daemon with synthetic events.
- `tests/run.sh` — full suite: contracts, QML lint, model and keyboard tests, fake-daemon IPC, and layout smokes. Needs `OMARCHY_PATH` (default `/usr/share/omarchy`) and a Wayland display.
- `tests/run-portable.sh` — the subset that needs only Python and Qt QML Test: Python contracts, `manifest.json`, shell syntax, and `tst_model.qml`. No display.
- `tests/run-headless-omarchy.sh` — starts headless Weston and runs `tests/run.sh`. Pull-request CI uses this.
- `docs/` — compatibility, release procedure, marketplace, and stable acceptance. Shipping steps are in `docs/RELEASE.md`.
- `release.json` — widget version paired with the tested OmaCalendar app version.
- `.github/workflows/ci.yml` — job `current-omarchy`. `.github/workflows/secret-scan.yml` — job `gitleaks` (name Gitleaks). `.github/workflows/release.yml` runs on version tags and `workflow_dispatch`, not on pull requests.

## Commands

Required pull-request checks are `current-omarchy` and Gitleaks. Run the shell commands below as CI writes them.

**current-omarchy** (`.github/workflows/ci.yml`). The job first fetches Omarchy commit `346e69e1cec6c4e8924531874af6ba010a1bc99e` into `$RUNNER_TEMP/omacalendar-omarchy` and prepends that tree's `bin` to `PATH`.

```sh
shellcheck tests/*.sh scripts/release/*.sh
ruby -e 'require "yaml"; ARGV.each { |path| YAML.parse_file(path) }' \
  .github/workflows/*.yml
python tests/check_whitespace.py
export OMARCHY_PATH="$RUNNER_TEMP/omacalendar-omarchy"
export PATH="$OMARCHY_PATH/bin:$PATH"
./tests/run-headless-omarchy.sh
```

`./tests/run-headless-omarchy.sh` calls `./tests/run.sh`. It needs Weston, Quickshell, Qt 6 (`qmllint`, `qmltestrunner`), Python 3, and that Omarchy tree.

**Gitleaks** has no local command in CI or docs. `.github/workflows/secret-scan.yml` checks out full history and runs `gitleaks/gitleaks-action` with `GITLEAKS_CONFIG: .gitleaks.toml`.

The release workflow, not pull-request CI, runs `./tests/run-portable.sh` after the Omarchy gate. README.md documents `./tests/run.sh` when `OMARCHY_PATH` points at an installed Omarchy tree, and `./tests/run-portable.sh` for the Python and Qt QML Test subset.

Regenerate `preview.png` with the synthetic capture. It must not read a live calendar or the desktop:

```sh
./tools/preview/capture-preview.sh
```

Do not run install, update, or remove commands during ordinary work. They change the Omarchy shell layout. See README.md and `docs/RELEASE.md`.

## Definition of done

- Start from a GitHub Issue that states the goal, non-goals, acceptance criteria, and how to prove them.
- The `current-omarchy` commands above pass locally. Paste that output in the PR body. If a command could not be run, name it and why. Gitleaks runs in CI; do not invent a local Gitleaks invocation.
- Every bug fix adds a regression test that fails before the fix.
- A change visible in the bar or popup includes a screenshot.
- The PR links the Issue and states what was not done.

## Boundaries

- Never push to `main`. That branch is the release-only install channel. It advances only to the exact commit of a reviewed, signed, published release tag.
- Never force-push to shared branches, delete branches or tags, or create tags or releases. A release is a GPG-signed annotated tag; `scripts/release/verify-release.sh` accepts a PGP or SSH signature. The tag workflow opens a draft release that a person publishes. Agents never tag or publish. See `docs/RELEASE.md`.
- No major dependency bumps. No changes to `.github/`, release config, auth, database migrations, or secrets unless the Issue asks. This plugin ships no lockfile, no auth module, and no database.
- Never connect to the live daemon socket during automated work. Tests use only `tests/fake_daemon.py`.
- Do not access real calendar credentials, provider APIs, Secret Service, or the OmaCalendar SQLite database.
- Install and uninstall operations change the Omarchy shell layout. Perform them only during an explicit release qualification.
- Never weaken or delete a test to make CI pass.
- Keep a pull request to about 400 changed lines. Split work that would exceed that.
- When a requirement is ambiguous, ask in the PR instead of guessing.

## Commits and PRs

Use Conventional Commits: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `build(deps):`, `chore:`. The PR title uses the same form, because squash merges take the title as the commit subject. Never add `Co-Authored-By` or any other AI co-author or attribution trailer to a commit message or a PR body.

## Review guidance

Bugbot, Codex, and Claude should focus on IPC correctness (protocol major 2, capability gating from `system.info`, mutation envelopes, undo, and Tasks only when IPC 2.2 lists `taskLists.list` and `tasks.list`), presentation-only snapshots (no credentials, provider URLs, ETags, sync tokens, or raw payloads), the fake-daemon test boundary, QML keyboard and layout behavior, and meeting links using `xdg-open` with no arbitrary commands taken from daemon data. The agent that opened the PR fixes review findings. The maintainer merges.

## Learning

Read [`docs/agent-mistakes.md`](docs/agent-mistakes.md) before starting. When a reviewer catches a repeatable mistake, add an entry to that file.
