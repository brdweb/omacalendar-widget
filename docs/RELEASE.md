# Release procedure

The widget and app have independent versions. Update manifest.json,
release.json, the changelog and compatibility matrix, then run the complete
widget suite. Record automated evidence and owner acceptance in
stable-acceptance.json. The accepted runtime commit must be an ancestor of
the release; later QML/JavaScript changes invalidate acceptance.

Create a signed annotated release tag with the maintainer's verified GitHub
identity. Verify it with scripts/release/verify-release.sh and push it. The
workflow checks the signed app release contract, tests against the Omarchy
reference, creates a deterministic archive, adds SPDX/provenance attestations
and opens a draft. Download and verify every checksum and attestation before
publishing. Never move a public tag or replace a published asset.

Promote the release-only `main` install branch to the signed release commit.
Verify the remote default branch and tag after promotion:

```bash
git ls-remote --symref origin HEAD
release_tag=v0.1.0
git ls-remote origin "refs/tags/${release_tag}^{}"
```

Use the [marketplace guide](MARKETPLACE.md) for listing details. A marketplace
listing is independently maintained and is not a blanket security certification.
