# Omarchy marketplace submission

The OmaCalendar widget is published independently from the desktop application.
Submit only after the widget repository is public, `v0.1.0-beta.1` is published,
and the exact marketplace candidate commit is available on the default branch.

The authoritative publisher guide is
[Omarchy Plugins: Publish your plugin](https://plugins.omarchy.org/publish.html).
Its current canonical submission repository is
[`omacom/omarchy-plugin-marketplace`](https://github.com/omacom/omarchy-plugin-marketplace),
whose [CLI and AI submission contract](https://github.com/omacom/omarchy-plugin-marketplace/blob/main/SUBMISSION.md)
defines the headings, controlled category and tags, and owner confirmation used
below.

## Repository checklist

- Public repository: `https://github.com/brdweb/omacalendar-widget`
- One plugin with `manifest.json` at the repository root
- Permanent plugin ID: `org.omacalendar.widget`
- Root `README.md` with requirements, installation, update, and removal
- Root `LICENSE`
- External dependency documented: OmaCalendar `omacalendard` with IPC major 2
- Current Omarchy validation passes: `omarchy plugin validate .`
- Complete widget suite passes: `./tests/run.sh`
- Real, privacy-safe root preview image named `preview.png`
- Published widget beta and exact compatibility record:
  widget `0.1.0-beta.1`, OmaCalendar `1.0.0-alpha`, IPC major 2

The recorded app version is the build used to qualify the widget's IPC
compatibility. It does not require matching app/widget version numbers or a
simultaneous release.

The marketplace runs plugins unsandboxed and validates the listing rather than
performing a complete security audit. Keep provider credentials, databases,
runtime sockets, and private calendar data out of the repository and preview.
Although a preview is optional to the marketplace, it is required for this
project's beta listing. Use a real widget capture with synthetic events, no
personal calendar data, and no mockup. The marketplace accepts a preview up to
50 MB and 40 megapixels, strips its metadata, and generates optimized images.

## Recommended listing

- Title: `[Plugin]: OmaCalendar`
- Category: `Widgets`
- Tags: `bar, quickshell`
- Suggested missing tag: `calendar`
- Repository URL: `https://github.com/brdweb/omacalendar-widget`

Before opening the submission, search the registry and existing issues for the
permanent plugin ID and confirm it is still available. The ID
`org.omacalendar.widget` is intentionally preserved across releases.

## Submission body

[`MARKETPLACE_SUBMISSION.md`](MARKETPLACE_SUBMISSION.md) is the exact issue body.
Keep its six headings in their current order and do not change the five official
checklist statements. The submission title is `[Plugin]: OmaCalendar`.

Submit through the official
[Omarchy plugin form](https://github.com/omacom/omarchy-plugin-marketplace/issues/new?template=submit-plugin.yml).
For an approved CLI submission, use:

```bash
gh issue create \
  --repo omacom/omarchy-plugin-marketplace \
  --title "[Plugin]: OmaCalendar" \
  --body-file docs/MARKETPLACE_SUBMISSION.md
```

Automated compatibility validation and the Automated Security Baseline will
scan the exact observed commit and comment on the issue. A marketplace
maintainer must review that evidence and apply `approved-and-verified` before
publication. Fix the existing repository or issue if validation fails; do not
open a duplicate submission.

Creating the marketplace issue is an external publication action. Review the
completed title and body, confirm ownership of the repository and preview, and
explicitly approve submission before it is opened.
