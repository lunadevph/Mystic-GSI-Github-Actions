#!/usr/bin/env bash
# Sync the Android source tree described by the manifest inputs.
set -euo pipefail

: "${MANIFEST_URL:?MANIFEST_URL is required}"
: "${MANIFEST_BRANCH:?MANIFEST_BRANCH is required}"

SOURCE_DIR="${SOURCE_DIR:-$(pwd)/source}"
JOBS="${JOBS:-$(nproc --all)}"
export PATH="${HOME}/bin:${PATH}"

mkdir -p "${SOURCE_DIR}"
cd "${SOURCE_DIR}"

if [ ! -d .repo ]; then
  echo "::group::repo init"
  # Shallow clone keeps the checkout small; drop --depth if you need full history.
  repo init -u "${MANIFEST_URL}" -b "${MANIFEST_BRANCH}" --depth=1
  echo "::endgroup::"
else
  echo "Reusing existing .repo checkout"
fi

echo "::group::repo sync"
repo sync -c -j"${JOBS}" --force-sync --no-clone-bundle --no-tags
echo "::endgroup::"

echo "Source tree ready at ${SOURCE_DIR}"
