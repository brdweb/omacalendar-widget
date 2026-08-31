# Omarchy marketplace submission

The OmaCalendar widget is published independently from the desktop application.
Submit only after the widget repository is public and its alpha tag or accepted
release commit is available on GitHub.

## Repository checklist

- Public repository: `https://github.com/brdweb/omacalendar-widget`
- One plugin with `manifest.json` at the repository root
- Permanent plugin ID: `org.omacalendar.widget`
- Root `README.md` with requirements, installation, update, and removal
- Root `LICENSE`
- External dependency documented: OmaCalendar `omacalendard` with IPC major 2
- Current Omarchy validation passes: `omarchy plugin validate .`
- Complete widget suite passes: `./tests/run.sh`
- Optional root preview image named `preview.png`, `preview.jpg`,
  `preview.jpeg`, `preview.webp`, or `preview.avif`

The marketplace runs plugins unsandboxed and validates the listing rather than
performing a complete security audit. Keep provider credentials, databases,
runtime sockets, and private calendar data out of the repository and preview.

## Recommended listing

- Title: `[Plugin]: OmaCalendar`
- Category: `Widgets`
- Tags: `bar, quickshell`
- Suggested missing tag: `calendar`
- Repository URL: `https://github.com/brdweb/omacalendar-widget`

Before opening the submission, search the marketplace for the permanent plugin
ID and confirm it is still available.

## Submission body

```markdown
### Repository URL

https://github.com/brdweb/omacalendar-widget

### Category

Widgets

### Tags

bar, quickshell

### Suggest a missing tag

calendar

### Maintainer notes

Requires the separately installed OmaCalendar daemon with IPC major 2. The
desktop application does not need to remain open; systemd socket activation
starts the daemon on demand.

### Submission checklist
- [x] The repository is public and contains installation and removal instructions.
- [x] I have documented the plugin license and any external dependencies.
- [x] I confirm that I own or have permission to submit this plugin and its preview assets.
- [x] The plugin does not overwrite user configuration without explicit consent.
- [x] I understand that approval is for listing and is not a security review.
```

Submit through the official
[Omarchy plugin form](https://github.com/omacom/omarchy-plugin-marketplace/issues/new?template=submit-plugin.yml).
Automated compatibility validation and the security baseline will comment on
the issue. Fix the existing repository or issue if validation fails; do not
open a duplicate submission.

Creating the marketplace issue is an external publication action. Review the
completed title and body and explicitly approve submission before it is opened.
