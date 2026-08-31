# Security policy

OmaCalendar widget `0.1.0-alpha` is an unsupported evaluation prerelease. It is
not suitable for production or as the only way to access calendar data.

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
