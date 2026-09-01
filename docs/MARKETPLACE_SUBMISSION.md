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
Widget 0.1.0-beta.1 is qualified with OmaCalendar 1.0.0-alpha, but the projects'
versions and release schedules are independent. The desktop application does
not need to remain open; systemd user socket activation starts the daemon on
demand. Install the qualified app source with:

```bash
git clone --branch v1.0.0-alpha --depth 1 https://github.com/brdweb/omacalendar.git
cd omacalendar
omarchy pkg add cmake ninja gcc qt6-base qt6-declarative qt6-networkauth libical libsecret pkgconf
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_INSTALL_PREFIX="$HOME/.local"
cmake --build build --parallel
ctest --test-dir build --output-on-failure
cmake --install build
systemctl --user daemon-reload
systemctl --user enable --now omacalendard.socket
```

The app's complete installation and first-run guide is at
https://github.com/brdweb/omacalendar/blob/main/docs/GETTING_STARTED.md.
Google Calendar access is currently in Google's OAuth verification stage and
is not yet approved for unrestricted public use; authorization may remain
limited to configured test users and Google may show its unverified-app
warning. The widget itself accesses only the user-local OmaCalendar socket and
does not contact Google or any calendar provider.

Current Omarchy add/update commands follow the repository's remote default
HEAD. The release-only `main` branch stays at the exact commit of signed tag `v0.1.0-beta.1`;
development commits are not merged there.
Users who require an immutable snapshot can use the checksummed,
GitHub-attested signed-release archive documented in the root README.

### Submission checklist

- [x] The repository is public and contains installation and removal instructions.
- [x] I have documented the plugin license and any external dependencies.
- [x] I confirm that I own or have permission to submit this plugin and its preview assets.
- [x] The plugin does not overwrite user configuration without explicit consent.
- [x] I understand that approval is for listing and is not a security review.
