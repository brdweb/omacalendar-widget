# Security policy

OmaCalendar widget `0.1.0-beta.1` is an unsupported public-testing prerelease.
It is not suitable for production or as the only way to access calendar data.

Report suspected vulnerabilities privately with GitHub's **Report a
vulnerability** form for this repository. Do not open a public issue containing
calendar text, attendee addresses, private server URLs, tokens, passwords, or
other credentials. Revoke or rotate any credential that may have been exposed.

The widget's intended boundary is narrow: it reads presentation DTOs and sends
user actions over the local OmaCalendar IPC socket. It must never read the
daemon database or Secret Service, store calendar snapshots, carry provider
credentials, or contact remote calendar services. A local attacker already
able to execute arbitrary code as the same Unix user is outside that isolation
boundary.

Current Omarchy plugin installation is Git-based and cannot pin a tag or
commit: add/update follows the repository's remote default `HEAD`. This
repository therefore treats default branch `main` as a release-only install
boundary. It advances only by fast-forward to the exact commit of a reviewed,
signed, published release tag; development remains on other branches. Users who
need an immutable source should install the checksummed, GitHub-attested release
archive documented in `README.md`.
