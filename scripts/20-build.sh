#!/usr/bin/env bash
# Apply local patches, then build the requested GSI variant.
set -euo pipefail

: "${LUNCH_TARGET:?LUNCH_TARGET is required}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="${SOURCE_DIR:-${REPO_ROOT}/source}"
JOBS="${JOBS:-$(nproc --all)}"

cd "${SOURCE_DIR}"

echo "::group::Apply local patches"
shopt -s nullglob
for patch_dir in "${REPO_ROOT}"/patches/*/; do
  [ -d "${patch_dir}" ] || continue
  project="$(basename "${patch_dir}")"
  target="${SOURCE_DIR}/${project}"

  if [ ! -d "${target}" ]; then
    echo "::warning::Skipping patches for '${project}' (project not in this manifest)"
    continue
  fi

  for patch in "${patch_dir}"*.patch; do
    echo "Applying ${project}/$(basename "${patch}")"
    git -C "${target}" apply --verbose "${patch}"
  done
done
shopt -u nullglob
echo "::endgroup::"

echo "::group::Configure build"
# shellcheck disable=SC1091
source build/envsetup.sh
lunch "${LUNCH_TARGET}"
echo "::endgroup::"

echo "::group::make systemimage"
make -j"${JOBS}" systemimage
echo "::endgroup::"

# Persist $OUT for the packaging step (each workflow step is a fresh shell).
mkdir -p out
printf '%s\n' "${OUT}" > out/.mystic_out

echo "Built image: ${OUT}/system.img"
