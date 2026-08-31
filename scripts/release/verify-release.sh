#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 vMAJOR.MINOR.PATCH[-PRERELEASE]" >&2
  exit 2
fi

release_tag=$1
if [[ ! ${release_tag} =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z]+([.-][0-9A-Za-z]+)*)?$ ]]; then
  echo "release tag must be vMAJOR.MINOR.PATCH[-PRERELEASE]" >&2
  exit 2
fi
release_version=${release_tag#v}
repository_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

if [[ $(git -C "${repository_root}" cat-file -t "${release_tag}" 2>/dev/null || true) != tag ]]; then
  echo "${release_tag} must be an annotated tag" >&2
  exit 1
fi
if ! git -C "${repository_root}" cat-file tag "${release_tag}" | \
  grep -Eq '^-----BEGIN (PGP|SSH) SIGNATURE-----$'; then
  echo "${release_tag} must carry a PGP or SSH signature" >&2
  exit 1
fi

tag_commit=$(git -C "${repository_root}" rev-parse "${release_tag}^{commit}")
head_commit=$(git -C "${repository_root}" rev-parse HEAD)
if [[ ${tag_commit} != "${head_commit}" ]]; then
  echo "${release_tag} does not point at the checked-out commit" >&2
  exit 1
fi
if [[ -n $(git -C "${repository_root}" status --porcelain --untracked-files=all) ]]; then
  echo "release verification requires a clean checkout" >&2
  exit 1
fi

app_version=$(python3 - "${repository_root}/manifest.json" \
  "${repository_root}/release.json" "${release_version}" <<'PY'
from __future__ import annotations

import json
import pathlib
import sys


manifest = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
release = json.loads(pathlib.Path(sys.argv[2]).read_text(encoding="utf-8"))
version = sys.argv[3]
if manifest.get("id") != "org.omacalendar.widget":
    raise SystemExit("manifest ID must remain org.omacalendar.widget")
if manifest.get("version") != version:
    raise SystemExit(
        f"tag version {version} does not match manifest version {manifest.get('version')}"
    )
compatibility = manifest.get("compatibility", {})
if compatibility.get("omacalendarProtocolMajor") != 2:
    raise SystemExit("release manifest must require OmaCalendar IPC major 2")
if release.get("widgetVersion") != version:
    raise SystemExit("release.json widgetVersion does not match the widget tag")
if release.get("omacalendarProtocolMajor") != 2:
    raise SystemExit("release.json must require OmaCalendar IPC major 2")
expected_channel = "stable"
if "-" in version:
    expected_channel = version.split("-", 1)[1].split(".", 1)[0]
if release.get("releaseChannel") != expected_channel:
    raise SystemExit(
        f"release.json releaseChannel must be {expected_channel} for {version}"
    )
app_version = release.get("testedOmaCalendarVersion")
if not isinstance(app_version, str) or not app_version:
    raise SystemExit("release.json must record testedOmaCalendarVersion")
print(app_version)
PY
)

if ! grep -Eq "^## \\[${release_version//./\\.}\\] - [0-9]{4}-[0-9]{2}-[0-9]{2}$" \
  "${repository_root}/CHANGELOG.md"; then
  echo "CHANGELOG.md has no dated ${release_version} release section" >&2
  exit 1
fi
if ! grep -Fq "| \`${release_version}\` | \`${app_version}\` | 2 |" \
  "${repository_root}/docs/COMPATIBILITY.md"; then
  echo "compatibility matrix has no widget ${release_version} / app ${app_version} row" >&2
  exit 1
fi

for required_file in \
  SECURITY.md \
  release.json \
  docs/BETA_ACCEPTANCE.md \
  docs/COMPATIBILITY.md \
  docs/MARKETPLACE.md \
  docs/MARKETPLACE_SUBMISSION.md \
  docs/RELEASE.md; do
  if [[ ! -s "${repository_root}/${required_file}" ]]; then
    echo "required release documentation is missing: ${required_file}" >&2
    exit 1
  fi
done

preview_count=0
preview_path=
for extension in png jpg jpeg webp avif; do
  candidate="${repository_root}/preview.${extension}"
  if [[ -e ${candidate} || -L ${candidate} ]]; then
    if [[ ! -f ${candidate} || -L ${candidate} ]]; then
      echo "marketplace preview must be a regular, non-symlink file: ${candidate}" >&2
      exit 1
    fi
    preview_count=$((preview_count + 1))
    preview_path=${candidate}
  fi
done
if [[ ${preview_count} -ne 1 ]]; then
  echo "release requires exactly one real root marketplace preview image" >&2
  exit 1
fi
preview_size=$(stat -c %s "${preview_path}")
if [[ ${preview_size} -le 0 || ${preview_size} -gt 52428800 ]]; then
  echo "marketplace preview must be non-empty and no larger than 50 MB" >&2
  exit 1
fi
python3 "${repository_root}/tools/preview/validate_preview.py" "${preview_path}"

echo "release metadata for ${release_tag} is internally consistent with OmaCalendar v${app_version}"
