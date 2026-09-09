# Widget 0.1.0 release candidate acceptance

The prepared candidate is widget `0.1.0-rc.1` with native OmaCalendar
`1.0.0-rc.1`, IPC 2.0 or newer. It is a GitHub draft for owner testing on
2026-09-09, not a stable release. No manual acceptance is recorded yet.
The [JSON evidence record](stable-acceptance.json) is deliberately pending;
the stable release workflow rejects it until every required result is recorded.

Use synthetic, disposable test events and a dedicated test calendar. Record
test names and outcomes without calendar contents, email addresses, credentials,
or private server URLs. Keep any local backup outside the repositories.

## 1. Download and verify the exact candidate

Sign in to `gh` with the repository-owner account. Draft releases are visible to
accounts with repository write access; unauthenticated public download links
do not work until publication. Install the app's native Arch candidate using
its tagged [installation guide](https://github.com/brdweb/omacalendar/blob/v1.0.0-rc.1/docs/INSTALL.md)
and [owner test plan](https://github.com/brdweb/omacalendar/blob/v1.0.0-rc.1/docs/OWNER_TESTING.md).
The expected Arch file is `omacalendar-1.0.0rc1-1-x86_64.pkg.tar.zst`.
The Omarchy widget requires the native host daemon and `omacalendard.socket`;
the Flatpak desktop alone does not provide this host integration. Debian and
Flatpak desktop installation are separate app gates. The app's normal widget
activation remains pinned to the public beta until a newer widget is accepted;
use the explicit verified RC installation below for this test.

Download the widget to a new directory. These commands verify every asset's
checksum, archive provenance, and SPDX attestation before extraction:

```bash
set -euo pipefail
release_version=0.1.0-rc.1
release_tag="v${release_version}"
candidate_dir=$(mktemp -d /tmp/omacalendar-widget-acceptance.XXXXXX)
gh release download "${release_tag}" --repo brdweb/omacalendar-widget \
  --dir "${candidate_dir}"
cd "${candidate_dir}"
sha256sum --check SHA256SUMS
archive="omacalendar-widget-${release_version}-source.tar.gz"
gh attestation verify "${archive}" --repo brdweb/omacalendar-widget \
  --source-ref "refs/tags/${release_tag}" \
  --signer-workflow brdweb/omacalendar-widget/.github/workflows/release.yml
gh attestation verify "${archive}" --repo brdweb/omacalendar-widget \
  --predicate-type https://spdx.dev/Document/v2.3 \
  --source-ref "refs/tags/${release_tag}" \
  --signer-workflow brdweb/omacalendar-widget/.github/workflows/release.yml
tar -xzf "${archive}"
source_dir="${candidate_dir}/omacalendar-widget-${release_version}"
omarchy plugin validate "${source_dir}"
```

All instructions and the evidence template are inside the source archive.
The release also includes `TESTING.md` and `stable-acceptance.json` directly.
Keep the verified archive and its checksum manifest until the test is accepted.

Capture candidate identity and runtime versions in private test notes:

```bash
set -euo pipefail
tag_object=$(gh api repos/brdweb/omacalendar-widget/git/ref/tags/v0.1.0-rc.1 \
  --jq '.object.sha')
gh api "repos/brdweb/omacalendar-widget/git/tags/${tag_object}" \
  --jq '{tag: .tag, commit: .object.sha, verified: .verification.verified}'
omacalendarctl system.info '{}'
quickshell --version
omarchy version
systemctl --user is-enabled omacalendard.socket
```

Use the full 40-character widget commit as `evidenceCommit`. Record the app
package/version and candidate SHA, Omarchy/Quickshell versions, monitor
edges/resolutions/scales, test date, and tester. Do not infer manual acceptance
from a tag or a passing workflow.

## 2. Install with a recoverable layout change

Close any event editor before switching widgets. Check the installation state:

```bash
omacalendar-widgetctl status
```

For a helper-managed installation, run `omacalendar-widgetctl restore` first;
the helper does not upgrade an existing active journal to a different source.
Verify the old clock/anchor/shortcut were restored before installing the RC.
For an existing archive or Git-managed widget, replace only the snapshot using
the following steps; placement and widget settings remain in Omarchy's external
configuration. Keep the returned backup path in your test notes:

```bash
set -euo pipefail
plugins_dir="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins"
target="${plugins_dir}/org.omacalendar.widget"
backup="${plugins_dir}/.org.omacalendar.widget.before-rc.$(date -u +%Y%m%d%H%M%S)"
[[ -d ${target} && ! -L ${target} && ! -e ${backup} ]]
omarchy plugin validate "${source_dir}"
mv "${target}" "${backup}"
if ! cp -a "${source_dir}" "${target}"; then
  if [[ -e ${target} ]]; then
    mv "${target}" "${backup}.incomplete"
  fi
  mv "${backup}" "${target}"
  exit 1
fi
omarchy-shell shell rescanPlugins
echo "Previous widget retained at ${backup}"
```

To roll back that snapshot swap, retain the RC alongside the original backup:

```bash
set -euo pipefail
[[ -d ${target} && ! -L ${target} && -d ${backup} && ! -e ${backup}.rc ]]
mv "${target}" "${backup}.rc"
mv "${backup}" "${target}"
omarchy-shell shell rescanPlugins
```

For a fresh install with no existing widget/journal, the transactional helper
validates the source and records clock placement, bar anchor, and shortcut:

```bash
set -euo pipefail
omacalendar-widgetctl install --source "${source_dir}"
```

Both paths install the verified RC snapshot. Do not use `omarchy plugin update`
to obtain the draft: it follows public `main`. Retain the helper's rollback
journal; do not manually delete it. If installation reports a conflict, save
the message and resolve the indicated state before repeating the test.

Restore a helper-managed installation's exact previous layout using:

```bash
omacalendar-widgetctl restore
```

Exercise restore as part of acceptance, verify the previous clock, center
anchor, and shortcut, then install the RC again if continuing tests. App data
and credentials are not owned by widget install/remove. An app package downgrade
is separate from widget restore; follow the app guide and keep the previous
package and a private data backup before testing an app upgrade.

## 3. Run the owner acceptance pass

Each row maps to `docs/stable-acceptance.json`. Mark `passed` only after the
stated behavior was exercised; record an outcome, environment, and any
evidence file or issue. A failure remains `failed` until fixed and retested.

| Gate | Exercise and expected result |
| --- | --- |
| `automated` | Exact candidate commit has successful CI, complete-history Gitleaks, native plugin validation, and full widget suite. Record workflow URLs and candidate SHA. |
| `artifacts` | Fresh download verifies checksums, source provenance, SPDX attestation, and archive plugin validation. Inspect SBOM and confirm the synthetic preview contains no personal data. |
| `install_upgrade_remove` | In a disposable Omarchy profile or test session, install the archive fresh, update an existing beta while preserving placement/settings, remove with `omarchy plugin remove org.omacalendar.widget`, then re-add the RC. Verify one bar instance and that app, daemon, test calendars, and credentials remain present. Do not use public `main` as the RC source. |
| `transactional_restore` | Install through `omacalendar-widgetctl`, then restore. Compare clock placement, center anchor, widget settings, and shortcut with the exact prior configuration. Reinstall only after restore passes. |
| `views_edges` | Open Month, Day, Week, and Agenda at top, bottom, left, and right bar edges; resize to the smallest supported available panel height. No clipped final week, obscured footer, offscreen popup, or unusable controls. |
| `keyboard` | Use arrows, Tab, Enter/Escape, `1`–`4`, `N`, `S`/`/`, `T`, and edit shortcuts. Search, clear, and close; scroll Agenda away from today and press Today twice. The footer stays visible and Today recenters each time. |
| `real_mutations` | With desktop UI closed, create/edit/move/delete/undo disposable events through the actual daemon. Set another writable default calendar and verify widget events honor it. Reopen the app and verify persisted events. Exercise a dedicated provider-backed test calendar as well as local events. |
| `resilience` | Restart `omacalendard.service` with an event visible; retain the cached snapshot while disconnected and refresh after reconnect. During a safe temporary provider outage, retain responsive cached views and recover on reconnect. Confirm missed-revision refresh in automated logs; fixtures alone do not prove real provider recovery. |
| `desktop_handoff` | Open the app once, return to the widget, then use Accounts. The popup closes and the existing app window focuses on account settings, with no duplicate process. |
| `mixed_scale_theme` | Hot-reload a theme and move/summon the widget across monitors at 100%, 125%, and 200%. Text remains readable, anchoring/focus/dismissal work on the intended monitor. Record actual monitor combinations; scale-factor fixtures alone do not close this row. |

Changing the real desktop layout is part of this explicit owner test. Record
and restore the starting configuration after each scenario. If hardware or a
provider scenario is unavailable, leave that gate pending and continue with
independent rows.

## 4. Record acceptance and finish the stable release

Commit completed JSON evidence and concise supporting notes on the candidate
branch. Set `acceptedBy`, timezone-qualified `acceptedAt`, and the full tested
`evidenceCommit` only when the owner accepts the results. Evidence can reference
private local test notes by descriptive filename; do not publish their private
contents. Repeat checks affected by later fixes. The verifier compares runtime
QML/JavaScript and manifest behavior against that evidence commit.

Once app and widget gates pass, prepare new stable tags `v1.0.0` and `v0.1.0`
with updated metadata and compatibility rows. Never move RC tags. Publish and
verify the app first, then prepare and verify the widget draft against that
published app. Run:

```bash
python3 scripts/release/verify-acceptance.py v0.1.0
```

It is expected to fail today because manual evidence is pending. It requires
successful rows, evidence, owner, date, and the tested runtime commit in release
history. After stable artifact verification, publish the widget, promote
release-only `main` by fast-forward to its signed tag, and verify remote
HEAD/main/tag identity using [the release procedure](RELEASE.md). Request a new
marketplace snapshot review on existing
[issue #5421](https://github.com/omacom/omarchy-plugin-marketplace/issues/5421);
the beta listing's approval does not automatically approve another commit.
