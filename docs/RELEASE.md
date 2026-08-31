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
   accepted IPC major.
3. Confirm the signed OmaCalendar app candidate tag recorded in `release.json`
   exists. The app and widget version numbers need not match.
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

The tag workflow requires the app tag recorded in `release.json`, reruns
portable and current-Omarchy gates, creates a deterministic source archive,
writes and checks `SHA256SUMS`, generates an SPDX JSON SBOM, and produces GitHub
provenance and SBOM attestations. It opens a draft release and refuses to
overwrite an already published release.

## Verify and publish together

Download the draft assets into a clean environment, run
`sha256sum --check SHA256SUMS`, verify both GitHub attestations, inspect the
SBOM, and install the archive on the release-reference machine. Repeat the
owner smoke and exact restore workflows. Publish the widget only after its
recorded app compatibility target and all widget gates pass. Never retag or
replace a published asset; fix a released mistake with a new patch version.

## Submit to Omarchy Plugins

After the beta release is public and the same accepted commit is on the default
branch, review the exact title and body in [`MARKETPLACE.md`](MARKETPLACE.md),
confirm all five owner statements, and create the one submission issue. The
marketplace bot reruns compatibility validation and its limited static baseline;
a maintainer must apply `approved-and-verified` before the listing is published.
