#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 vMAJOR.MINOR.PATCH[-PRERELEASE] OUTPUT_DIRECTORY" >&2
  exit 2
fi

release_tag=$1
output_directory=$2
if [[ ! ${release_tag} =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z]+([.-][0-9A-Za-z]+)*)?$ ]]; then
  echo "release tag must be vMAJOR.MINOR.PATCH[-PRERELEASE]" >&2
  exit 2
fi
release_version=${release_tag#v}

repository_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
if [[ $(git -C "${repository_root}" cat-file -t "${release_tag}" 2>/dev/null || true) != tag ]]; then
  echo "${release_tag} must name an annotated tag" >&2
  exit 1
fi

mkdir -p "${output_directory}"
output_directory=$(cd "${output_directory}" && pwd)
archive_name="omacalendar-widget-${release_version}-source.tar.gz"
archive_path="${output_directory}/${archive_name}"
package_root="omacalendar-widget-${release_version}/"
temporary_root=$(mktemp -d /tmp/omacalendar-widget-package.XXXXXX)

cleanup() {
  rm -rf -- "${temporary_root}"
}
trap cleanup EXIT

build_archive() {
  local destination=$1
  local tar_path="${destination%.gz}"
  git -C "${repository_root}" archive \
    --format=tar \
    --prefix="${package_root}" \
    --output="${tar_path}" \
    "${release_tag}"
  gzip -n -9 <"${tar_path}" >"${destination}"
  rm -f -- "${tar_path}"
}

first_archive="${temporary_root}/first.tar.gz"
second_archive="${temporary_root}/second.tar.gz"
build_archive "${first_archive}"
build_archive "${second_archive}"
if ! cmp -s "${first_archive}" "${second_archive}"; then
  echo "source archive generation was not deterministic" >&2
  exit 1
fi

install -m 0644 "${first_archive}" "${archive_path}"
"${repository_root}/scripts/release/verify-package.sh" \
  "${archive_path}" "${release_version}"
printf '%s\n' "${archive_path}"
