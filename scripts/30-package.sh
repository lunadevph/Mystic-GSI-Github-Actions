#!/usr/bin/env bash
# Compress the built system image, checksum it, and record build metadata.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="${SOURCE_DIR:-${REPO_ROOT}/source}"
ARTIFACT_DIR="${ARTIFACT_DIR:-${REPO_ROOT}/artifacts}"
VARIANT="${LUNCH_TARGET:-gsi}"

cd "${SOURCE_DIR}"
mkdir -p "${ARTIFACT_DIR}"

IMG=""
if [ -s out/.mystic_out ]; then
  OUT_DIR="$(cat out/.mystic_out)"
  if [ -f "${OUT_DIR}/system.img" ]; then
    IMG="${OUT_DIR}/system.img"
  fi
fi
if [ -z "${IMG}" ]; then
  IMG="$(find out/target/product -maxdepth 2 -name system.img -print -quit)"
fi
if [ -z "${IMG}" ] || [ ! -f "${IMG}" ]; then
  echo "::error::system.img was not produced by the build"
  exit 1
fi

NAME="MysticGSI_${VARIANT}_$(date -u +%Y%m%d)"
echo "::group::Compress ${IMG}"
xz -T0 -9 -c "${IMG}" > "${ARTIFACT_DIR}/${NAME}.img.xz"
echo "::endgroup::"

echo "::group::Checksums"
( cd "${ARTIFACT_DIR}" && sha256sum "${NAME}.img.xz" > "${NAME}.img.xz.sha256" )
cat "${ARTIFACT_DIR}/${NAME}.img.xz.sha256"
echo "::endgroup::"

cat > "${ARTIFACT_DIR}/build-info.txt" <<EOF
Mystic GSI build
================
variant:         ${VARIANT}
manifest:        ${MANIFEST_URL:-unknown}
branch:          ${MANIFEST_BRANCH:-unknown}
built (UTC):     $(date -u +"%Y-%m-%dT%H:%M:%SZ")
runner:          ${RUNNER_NAME:-local}
source commit:   $(git -C "${SOURCE_DIR}/build/make" rev-parse HEAD 2>/dev/null || echo "n/a")
system.img size: $(du -h "${IMG}" | cut -f1)
archive size:    $(du -h "${ARTIFACT_DIR}/${NAME}.img.xz" | cut -f1)
EOF

echo "::group::Artifacts"
ls -lh "${ARTIFACT_DIR}"
echo "::endgroup::"
