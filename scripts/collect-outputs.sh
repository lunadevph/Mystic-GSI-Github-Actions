#!/usr/bin/env bash
# Collect MysticGSI outputs, checksums, and build metadata for upload.
set -euo pipefail

MYSTIC_DIR="${MYSTIC_DIR:-$(pwd)/mysticgsi}"
BUILD_NAME="${BUILD_NAME:-mystic}"
ARTIFACT_DIR="${ARTIFACT_DIR:-$(pwd)/artifacts}"
FIRMWARE="${FIRMWARE:-}"
TYPE="${TYPE:-auto}"
FORMAT="${FORMAT:-ext4}"
COMPRESS="${COMPRESS:-true}"
NO_DEBLOAT="${NO_DEBLOAT:-false}"
NO_MERGE="${NO_MERGE:-false}"
ADD_TAG="${ADD_TAG:-}"

die() {
  echo "error: $*" >&2
  exit 1
}

sha256() {
  # Read via stdin so the output is just the digest (no filename escaping).
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum < "$1" | awk '{print $1}'
  else
    shasum -a 256 < "$1" | awk '{print $1}'
  fi
}

[ -d "${MYSTIC_DIR}/out" ] || die "no out/ directory in ${MYSTIC_DIR}; build did not run"

mapfile -t images < <(find "${MYSTIC_DIR}/out" -type f \( -name '*.img' -o -name '*.zip' \) | sort)
[ "${#images[@]}" -gt 0 ] || die "MysticGSI produced no .img or .zip files"

rm -rf "${ARTIFACT_DIR}"
mkdir -p "${ARTIFACT_DIR}"
cp -a "${MYSTIC_DIR}/out/." "${ARTIFACT_DIR}/"

if [ -f "${MYSTIC_DIR}/build.log" ]; then
  cp "${MYSTIC_DIR}/build.log" "${ARTIFACT_DIR}/build.log"
fi
if [ -f "${MYSTIC_DIR}/tmp/gsilist.json" ]; then
  cp "${MYSTIC_DIR}/tmp/gsilist.json" "${ARTIFACT_DIR}/gsilist.json"
fi

echo "::group::Checksums"
: > "${ARTIFACT_DIR}/SHA256SUMS"
while IFS= read -r file; do
  rel="${file#"${ARTIFACT_DIR}/"}"
  printf '%s  %s\n' "$(sha256 "${file}")" "${rel}" >> "${ARTIFACT_DIR}/SHA256SUMS"
done < <(find "${ARTIFACT_DIR}" -type f \( -name '*.img' -o -name '*.zip' \) | sort)
cat "${ARTIFACT_DIR}/SHA256SUMS"
echo "::endgroup::"

# Locate the firmware that was converted so its checksum is recorded.
firmware_file=""
if [[ "${FIRMWARE}" != *://* ]] && [ -f "${FIRMWARE}" ]; then
  firmware_file="${FIRMWARE}"
else
  firmware_file="$(find "${MYSTIC_DIR}/tmp/${BUILD_NAME}" -maxdepth 1 -type f \
    -printf '%s %p\n' 2>/dev/null | sort -nr | head -n 1 | cut -d' ' -f2- || true)"
fi

upstream_commit="$(git -C "${MYSTIC_DIR}" rev-parse HEAD 2>/dev/null || echo unknown)"

{
  echo "MysticGSI wrapper build"
  echo "======================="
  echo "upstream:        https://github.com/MysticGSI/mysticgsi"
  echo "upstream commit: ${upstream_commit}"
  echo "requested ref:   ${MYSTIC_REF:-unknown}"
  echo "build name:      ${BUILD_NAME}"
  echo "rom type:        ${TYPE}"
  echo "format:          ${FORMAT}"
  echo "compress:        ${COMPRESS}"
  echo "no debloat:      ${NO_DEBLOAT}"
  echo "no merge:        ${NO_MERGE}"
  echo "add tag:         ${ADD_TAG:-<none>}"
  echo "runner:          ${RUNNER_NAME:-local}"
  echo "built (UTC):     $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  if [ -n "${firmware_file}" ] && [ -f "${firmware_file}" ]; then
    echo "firmware:        $(basename "${firmware_file}")"
    echo "firmware size:   $(du -h "${firmware_file}" | cut -f1)"
    echo "firmware sha256: $(sha256 "${firmware_file}")"
  else
    # Strip query strings so signed URLs do not leak credentials into the artifact.
    echo "firmware:        ${FIRMWARE%%\?*}"
    echo "firmware sha256: unavailable (not retained by MysticGSI)"
  fi
  echo ""
  echo "outputs:"
  sed 's/^/  /' "${ARTIFACT_DIR}/SHA256SUMS"
} > "${ARTIFACT_DIR}/build-info.txt"

echo "::group::Artifacts"
find "${ARTIFACT_DIR}" -type f -printf '%10s  %p\n' | sort -k2
echo "::endgroup::"
