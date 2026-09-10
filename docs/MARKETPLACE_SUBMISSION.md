### Repository URL

https://github.com/brdweb/omacalendar-widget

### Category

Widgets

### Tags

bar, quickshell

### Suggest a missing tag

calendar

### Maintainer notes

Requires a separately installed OmaCalendar daemon exposing IPC 2.0 or newer.
Widget 0.1.1 is qualified with OmaCalendar 1.0.0, but the projects'
versions and release schedules are independent. The desktop application does
not need to remain open; systemd user socket activation starts the daemon on
demand. Install the qualified app's checksummed and attested native package with:

```bash
set -euo pipefail
app_version=1.0.0
package=omacalendar-1.0.0-1-x86_64.pkg.tar.zst
release_url="https://github.com/brdweb/omacalendar/releases/download/v${app_version}"
curl -fLO "${release_url}/${package}"
curl -fLO "${release_url}/SHA256SUMS"
grep " ${package}$" SHA256SUMS | sha256sum --check
gh attestation verify "${package}" --repo brdweb/omacalendar \
  --source-ref "refs/tags/v${app_version}" \
  --signer-workflow brdweb/omacalendar/.github/workflows/release.yml
sudo pacman -U --needed "${package}"
systemctl --user daemon-reload
systemctl --user enable --now omacalendard.socket
```

The app's complete installation and first-run guide is at
https://github.com/brdweb/omacalendar/blob/main/docs/GETTING_STARTED.md.
Google has approved the app's branding and Calendar data-access verification.
The app's release acceptance record remains authoritative for external-account
and provider testing. The widget itself accesses only the user-local
OmaCalendar socket and does not contact Google or any calendar provider.

Current Omarchy add/update commands follow the repository's remote default
HEAD. The release-only `main` branch stays at the exact commit of signed tag `v0.1.1`;
development commits are not merged there.
Users who require an immutable snapshot can use the checksummed,
GitHub-attested signed-release archive documented in the root README.

### Submission checklist

- [x] The repository is public and contains installation and removal instructions.
- [x] I have documented the plugin license and any external dependencies.
- [x] I confirm that I own or have permission to submit this plugin and its preview assets.
- [x] The plugin does not overwrite user configuration without explicit consent.
- [x] I understand that approval is for listing and is not a security review.
