#!/usr/bin/env bash
# Thin wrapper around `MysticGSI/cli.py build`. No conversion logic here.
set -euo pipefail

MYSTIC_DIR="${MYSTIC_DIR:-$(pwd)/mysticgsi}"
BUILD_NAME="${BUILD_NAME:-mystic}"
FIRMWARE="${FIRMWARE:-}"
TYPE="${TYPE:-auto}"
FORMAT="${FORMAT:-ext4}"
COMPRESS="${COMPRESS:-true}"
NO_DEBLOAT="${NO_DEBLOAT:-false}"
NO_MERGE="${NO_MERGE:-false}"
ADD_TAG="${ADD_TAG:-}"
AVB_KEY="${AVB_KEY:-}"
LOG_FILE="${LOG_FILE:-${MYSTIC_DIR}/build.log}"

die() {
  echo "error: $*" >&2
  exit 1
}

[ -n "${FIRMWARE}" ] || die "FIRMWARE is required (URL or path)"
[[ "${BUILD_NAME}" =~ ^[A-Za-z0-9._-]{1,64}$ ]] \
  || die "invalid build name '${BUILD_NAME}' (allowed: letters, digits, dot, dash, underscore; max 64)"
[ -x "${MYSTIC_DIR}/.venv/bin/python" ] \
  || die "${MYSTIC_DIR}/.venv/bin/python missing; run setup-mysticgsi.sh first"
[ -f "${MYSTIC_DIR}/cli.py" ] || die "${MYSTIC_DIR}/cli.py missing"

case "${FORMAT}" in
  ext4 | lz4 | lz4hc | lzma) ;;
  *) die "invalid format '${FORMAT}' (ext4, lz4, lz4hc, lzma)" ;;
esac
case "${COMPRESS}" in
  true | false) ;;
  *) die "COMPRESS must be true or false" ;;
esac

if [[ "${FIRMWARE}" != *://* ]] && [ ! -f "${FIRMWARE}" ]; then
  die "firmware file not found: ${FIRMWARE}"
fi

args=(build "${BUILD_NAME}" "${FIRMWARE}" --type "${TYPE}")
if [ "${FORMAT}" != "ext4" ]; then
  args+=(--format "${FORMAT}")
fi
if [ "${COMPRESS}" = "true" ]; then
  args+=(--compress)
fi
if [ "${NO_DEBLOAT}" = "true" ]; then
  args+=(--no-debloat)
fi
if [ "${NO_MERGE}" = "true" ]; then
  args+=(--no-merge)
fi
if [ -n "${ADD_TAG}" ]; then
  args+=(--add "${ADD_TAG}")
fi
if [ -n "${AVB_KEY}" ]; then
  [ -f "${AVB_KEY}" ] || die "AVB key not found: ${AVB_KEY}"
  args+=(--avb-key "${AVB_KEY}")
fi

cd "${MYSTIC_DIR}"

echo "::group::MysticGSI build"
echo "Build name : ${BUILD_NAME}"
echo "Firmware   : ${FIRMWARE}"
echo "Type       : ${TYPE}"
echo "Format     : ${FORMAT}"
echo "Compress   : ${COMPRESS}"
echo "Debloat    : $([ "${NO_DEBLOAT}" = "true" ] && echo "no" || echo "yes")"
echo "Merge      : $([ "${NO_MERGE}" = "true" ] && echo "no" || echo "yes")"
if [ -n "${ADD_TAG}" ]; then
  echo "Tag        : ${ADD_TAG}"
fi
if [ -n "${AVB_KEY}" ]; then
  echo "AVB key    : custom"
fi
echo "::endgroup::"

echo "Running: .venv/bin/python cli.py ${args[*]}"

set +e
.venv/bin/python cli.py "${args[@]}" 2>&1 | tee "${LOG_FILE}"
rc=${PIPESTATUS[0]}
set -e

if [ "${rc}" -ne 0 ]; then
  echo "::error::MysticGSI build failed (exit ${rc}); see the build.log artifact"
  exit "${rc}"
fi

echo "::group::Output tree"
find out -maxdepth 2 -type f -printf '%10s  %p\n' 2>/dev/null | sort -k2 || true
echo "::endgroup::"
