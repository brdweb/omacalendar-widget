# Release procedure

The widget and desktop app have independent versions and release cadences.
Automation creates a draft widget candidate only; maintainers publish it after
the recorded app compatibility target and widget owner-acceptance matrix pass.
The recorded app tag is qualification evidence, not a requirement that the
projects use matching versions or publish simultaneously.

## Current RC preparation

Widget `0.1.0-rc.4` and app `1.0.0-rc.4` are owner-test candidates. The user
authorized completing qualification and release on 2026-09-09; technical gates still apply. Keep both releases
as drafts and keep widget RC metadata on its candidate branch until accepted.
[`STABLE_ACCEPTANCE.md`](STABLE_ACCEPTANCE.md) is the current test/download/
rollback procedure; [`stable-acceptance.json`](stable-acceptance.json) holds the
pending evidence. The historical beta checklist is not stable approval.

RC4 fixes the real Omarchy 4.0.3 read-only bar API failure discovered during
running-shell acceptance. The application separately fixes calendar correctness,
startup restoration and widget activation readiness. Rebuild and verify the
new pair while preserving prior signed tags, drafts and source inventories.

Widget RC1 was superseded before release artifacts were produced. Its SSH
signature verified locally, but GitHub reported `unverified_email` for the
tagger identity, so the release gate correctly stopped. Preserve the signed
`v0.1.0-rc.1` tag unchanged; do not delete or move it. RC2 repaired the tagger
identity; retain the same verified owner identity explicitly when tagging RC4.
The [RC1 workflow](https://github.com/brdweb/omacalendar-widget/actions/runs/34303331925)
stopped at the signed-tag gate without creating a draft or release assets.

An RC draft verifies its own signed tag and clean source, the signed candidate
app tag and IPC constants, complete automated suites, preview, archive,
checksums, SBOM, and attestations. The app contract check uses `--candidate`
only for an explicit `rc.N` widget and app. It does not claim app publication,
package installation, or runtime acceptance. The repository-scoped workflow
token cannot read another repository's draft assets; the owner verifies those
downloads separately. Non-RC release paths continue to require a published app.

The SPDX attestation describes the exact widget source archive: a versioned
widget package and SHA-1/SHA-256 hashes for all shipped regular files. It does
not inventory the separately installed native app/daemon, Quickshell, Qt,
Omarchy, or their dependencies. Scanner-identified build/test tools are source
metadata, not bundled runtime libraries. Symlinks are not hashed as independent
file contents; license conclusions remain `NOASSERTION` with the shipped MIT
license available for review.

Prepare the app's signed RC tag first, then the widget's signed RC tag:

```bash
git config --local user.name 'Jason Mitchell'
git config --local user.email '58915+brdweb@users.noreply.github.com'
git -c user.name='Jason Mitchell' \
  -c user.email='58915+brdweb@users.noreply.github.com' \
  tag -s v0.1.0-rc.4 -m 'OmaCalendar widget 0.1.0-rc.4'
./scripts/release/verify-release.sh v0.1.0-rc.4
git push origin v0.1.0-rc.4
```

The tag workflow creates a draft automatically. For a retry, dispatch on the
same signed tag so provenance still records its exact tag ref:

```bash
gh workflow run release.yml --repo brdweb/omacalendar-widget --ref v0.1.0-rc.4
```

Do not dispatch a branch as though it were a release tag. A published release
is never overwritten. A changed candidate needs a new RC tag/version.
Stable tags additionally run `verify-acceptance.py`, which blocks on any
pending/failed gate, missing evidence/sign-off, or changed accepted runtime.

## Prepare and qualify

1. Pass `./tests/run.sh` on the release-reference Omarchy system and complete
   the real four-edge, mixed-scale multi-monitor, keyboard, theme-reload,
   daemon-restart, and offline-cache acceptance pass before stable publication.
   Draft RC preparation may precede the owner pass with explicit pending gates.
2. Update the widget version in `manifest.json` and `release.json`, the tested
   app version in `release.json`, this repository's changelog, and the exact row
   in `COMPATIBILITY.md`. Preserve manifest ID `org.omacalendar.widget` and the
   accepted IPC major and minimum minor. Set `trustedInstallTag` to the new
   signed widget tag and keep `trustedInstallBranch` equal to release-only
   `main`.
3. Confirm the OmaCalendar app tag recorded in `release.json` is annotated and
   GitHub-signature-verified, resolves directly to a commit, and exposes the
   recorded IPC major and minimum minor in its tagged source. Stable/non-RC
   widget qualification additionally requires a published non-draft app release.
   An explicit `rc.N` widget/app pair uses the signed-source-only `--candidate`
   check described above; app package and manual runtime acceptance stay pending.
   The app and widget version numbers need not match.
4. Run portable and complete tests from a clean checkout and review the secret
   scan. The widget archive must contain no credentials, database, runtime
   socket, or provider networking implementation.
5. Add one real, privacy-safe root `preview.png` captured from the widget with
   synthetic data. Do not use a mockup or include personal event, account,
   notification, or desktop data. Record the result in
   [`STABLE_ACCEPTANCE.md`](STABLE_ACCEPTANCE.md).
6. Check the existing marketplace listing and submission #5421, and validate
   the next promoted default-branch commit using the current
   [marketplace submission contract](https://github.com/omacom/omarchy-plugin-marketplace/blob/main/SUBMISSION.md).
   Do not open a duplicate submission for the already registered plugin ID.

## Create a candidate

For a future stable release, complete the stable acceptance record and create
a signed annotated tag only from the accepted commit:

```bash
git -c user.name='Jason Mitchell' \
  -c user.email='58915+brdweb@users.noreply.github.com' \
  tag -s v0.1.0 -m 'OmaCalendar widget 0.1.0'
./scripts/release/verify-release.sh v0.1.0
git push origin v0.1.0
```

The tag workflow verifies the recorded app's annotated tag, GitHub signature,
resolved commit, published release, and tagged IPC constants; reruns portable
and current-Omarchy gates; creates a deterministic source archive; writes and
checks `SHA256SUMS`; generates an SPDX JSON SBOM; and produces GitHub
provenance and SBOM attestations. It opens a draft release and refuses to
overwrite an already published release.

## Verify and publish together

Download the draft assets into a clean environment, run
`sha256sum --check SHA256SUMS`, verify both GitHub attestations, inspect the
SBOM, and install the archive on the release-reference machine. Repeat the
owner smoke and exact restore workflows. Publish the widget only after its
recorded app compatibility target and all widget gates pass. Never retag or
replace a published asset; fix a released mistake with a new patch version.

## Promote the release-only install branch

Current Omarchy `plugin add` has no ref option and clones remote default
`HEAD`; `plugin update` fetches that same `origin HEAD` and fast-forwards the
installed checkout. Consequently, `main` is an installation trust boundary,
not a development branch. Keep development on feature branches, protect `main`
from force-push and deletion, and advance it only after the corresponding signed
tag and GitHub release are public and accepted.

Promote the exact tag commit with a normal fast-forward, then prove that the
remote default branch, `main`, and the peeled signed tag are identical:

```bash
release_tag=v0.1.0
release_commit=$(git rev-parse "${release_tag}^{commit}")
test "$(gh release view "${release_tag}" --json isDraft --jq .isDraft)" = false
git fetch origin main
git merge-base --is-ancestor origin/main "${release_commit}"
git push origin "${release_commit}:refs/heads/main"

remote_default=$(git ls-remote --symref origin HEAD |
  awk '$1 == "ref:" && $3 == "HEAD" { print $2; exit }')
remote_head=$(git ls-remote origin HEAD | awk 'NR == 1 { print $1 }')
remote_main=$(git ls-remote origin refs/heads/main | awk 'NR == 1 { print $1 }')
remote_tag=$(git ls-remote origin "refs/tags/${release_tag}^{}" |
  awk 'NR == 1 { print $1 }')
test "${remote_default}" = refs/heads/main
test "${remote_head}" = "${release_commit}"
test "${remote_main}" = "${release_commit}"
test "${remote_tag}" = "${release_commit}"
```

If any check differs, stop publication and marketplace work. Never repair the
condition by moving or recreating a published tag or by force-pushing `main`.
Publish a new patch release when the accepted code must change.

## Submit to Omarchy Plugins

Initial submission #5421 is already approved and listed for the beta snapshot.
Do not create another issue. Only after the promotion checks above pass, request
a snapshot update on the existing listing for the new accepted commit. The
initial-submission reference in [`MARKETPLACE.md`](MARKETPLACE.md) and
`MARKETPLACE_SUBMISSION.md` records the prior owner statements.
The marketplace bot reruns compatibility
validation and its limited static baseline against the observed commit; a
maintainer must apply `approved-and-verified` before the listing is published.
For later releases, request verification of the new full `main` commit only
after that commit has passed the same signed-tag promotion checks.
