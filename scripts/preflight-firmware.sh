#!/usr/bin/env bash
# Validate a local firmware archive before handing it to MysticGSI.
# MysticGSI extracts .tgz/.tar.gz itself; this script only fails early with a
# clear message when a local archive is unreadable or truncated.
set -euo pipefail

FIRMWARE="${FIRMWARE:-}"

die() {
  echo "error: $*" >&2
  exit 1
}

# URLs are downloaded (and validated) by MysticGSI's own aria2c step.
if [[ "${FIRMWARE}" == *://* ]]; then
  echo "Firmware is a URL; MysticGSI will download and extract it."
  exit 0
fi
if [ -z "${FIRMWARE}" ]; then
  exit 0
fi
[ -f "${FIRMWARE}" ] || die "firmware file not found: ${FIRMWARE}"

lower="$(printf '%s' "${FIRMWARE}" | tr '[:upper:]' '[:lower:]')"

case "${lower}" in
  *.tgz | *.tar.gz)
    echo "::group::Preflight firmware archive"
    echo "File: $(basename "${FIRMWARE}") (.tgz)"
    if ! gzip -t "${FIRMWARE}" 2>/dev/null; then
      die "$(basename "${FIRMWARE}") failed the gzip integrity check (truncated or corrupt download)"
    fi
    if ! tar -tzf "${FIRMWARE}" >/dev/null 2>&1; then
      die "$(basename "${FIRMWARE}") is not a readable tar.gz archive"
    fi
    count="$(tar -tzf "${FIRMWARE}" 2>/dev/null | wc -l | tr -d ' ')"
    echo "OK: ${count} archive members"
    echo "First members:"
    tar -tzf "${FIRMWARE}" 2>/dev/null | head -n 15
    echo "MysticGSI will extract this archive."
    echo "::endgroup::"
    ;;
  *.tar | *.tar.md5)
    echo "::group::Preflight firmware archive"
    if ! tar -tf "${FIRMWARE}" >/dev/null 2>&1; then
      die "$(basename "${FIRMWARE}") is not a readable tar archive"
    fi
    echo "OK: plain tar archive; MysticGSI will extract it."
    echo "::endgroup::"
    ;;
  *.tar.bz2 | *.tbz2)
    if ! tar -tjf "${FIRMWARE}" >/dev/null 2>&1; then
      die "$(basename "${FIRMWARE}") is not a readable bzip2 tar archive"
    fi
    ;;
  *.tar.xz | *.txz)
    if ! tar -tJf "${FIRMWARE}" >/dev/null 2>&1; then
      die "$(basename "${FIRMWARE}") is not a readable xz tar archive"
    fi
    ;;
  *)
    echo "No archive preflight for $(basename "${FIRMWARE}"); handing it to MysticGSI as-is."
    ;;
esac
