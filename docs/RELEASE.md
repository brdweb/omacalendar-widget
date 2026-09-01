# Release procedure

The widget and desktop app have independent versions and release cadences.
Automation creates a draft widget candidate only; maintainers publish it after
the recorded app compatibility target and widget owner-acceptance matrix pass.
The recorded app tag is qualification evidence, not a requirement that the
projects use matching versions or publish simultaneously.

## Prepare and qualify

1. Pass `./tests/run.sh` on the release-reference Omarchy system and complete
   the real four-edge, mixed-scale multi-monitor, keyboard, theme-reload,
   daemon-restart, and offline-cache acceptance pass.
2. Update the widget version in `manifest.json` and `release.json`, the tested
   app version in `release.json`, this repository's changelog, and the exact row
   in `COMPATIBILITY.md`. Preserve manifest ID `org.omacalendar.widget` and the
   accepted IPC major and minimum minor. Set `trustedInstallTag` to the new
   signed widget tag and keep `trustedInstallBranch` equal to release-only
   `main`.
3. Confirm the OmaCalendar app tag recorded in `release.json` is annotated and
   GitHub-signature-verified, resolves directly to a commit, has a published
   non-draft GitHub release, and exposes the recorded IPC major and minimum minor
   in its tagged source. The app and widget version numbers need not match.
4. Run portable and complete tests from a clean checkout and review the secret
   scan. The widget archive must contain no credentials, database, runtime
   socket, or provider networking implementation.
5. Add one real, privacy-safe root `preview.png` captured from the widget with
   synthetic data. Do not use a mockup or include personal event, account,
   notification, or desktop data. Record the result in
   [`BETA_ACCEPTANCE.md`](BETA_ACCEPTANCE.md).
6. Confirm the permanent plugin ID is not present in the current marketplace
   registry or an existing submission, and validate the exact default-branch
   commit using the current
   [marketplace submission contract](https://github.com/omacom/omarchy-plugin-marketplace/blob/main/SUBMISSION.md).

## Create a candidate

For the current candidate, create a signed annotated tag only from the accepted
commit:

```bash
git tag -s v0.1.0-beta.1 -m 'OmaCalendar widget 0.1.0-beta.1'
./scripts/release/verify-release.sh v0.1.0-beta.1
git push origin v0.1.0-beta.1
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
release_tag=v0.1.0-beta.1
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

Only after the promotion checks above pass, review the exact title and body in
[`MARKETPLACE.md`](MARKETPLACE.md), confirm all five owner statements, and
create the one submission issue. The marketplace bot reruns compatibility
validation and its limited static baseline against the observed commit; a
maintainer must apply `approved-and-verified` before the listing is published.
For later releases, request verification of the new full `main` commit only
after that commit has passed the same signed-tag promotion checks.
