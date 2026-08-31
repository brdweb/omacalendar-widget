# Release procedure

The widget and desktop app have independent versions and release cadences.
Automation creates a draft widget candidate only; maintainers publish it after
the recorded app compatibility target and widget owner-acceptance matrix pass.

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

## Create a candidate

Create a signed annotated tag only from the accepted commit:

```bash
git tag -s vMAJOR.MINOR.PATCH-PRERELEASE -m 'OmaCalendar widget MAJOR.MINOR.PATCH-PRERELEASE'
./scripts/release/verify-release.sh vMAJOR.MINOR.PATCH-PRERELEASE
git push origin vMAJOR.MINOR.PATCH-PRERELEASE
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
