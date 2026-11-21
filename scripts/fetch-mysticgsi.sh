#!/usr/bin/env bash
# Clone MysticGSI itself at a pinned branch, tag, or commit.
# This repository is only a wrapper; all conversion logic lives upstream.
set -euo pipefail

MYSTIC_REPO="${MYSTIC_REPO:-https://github.com/MysticGSI/mysticgsi.git}"
MYSTIC_REF="${MYSTIC_REF:-main}"
MYSTIC_DIR="${MYSTIC_DIR:-$(pwd)/mysticgsi}"

echo "Fetching ${MYSTIC_REPO} @ ${MYSTIC_REF}"

rm -rf "${MYSTIC_DIR}"
mkdir -p "${MYSTIC_DIR}"

git -C "${MYSTIC_DIR}" init -q
git -C "${MYSTIC_DIR}" remote add origin "${MYSTIC_REPO}"

# Works for branches, tags, and full commit SHAs (GitHub allows fetching reachable SHAs).
if git -C "${MYSTIC_DIR}" fetch --depth 1 --no-tags origin "${MYSTIC_REF}"; then
  git -C "${MYSTIC_DIR}" -c advice.detachedHead=false checkout -q FETCH_HEAD
else
  echo "::warning::Shallow fetch of '${MYSTIC_REF}' failed; fetching full history"
  git -C "${MYSTIC_DIR}" fetch --no-tags origin \
    '+refs/heads/*:refs/remotes/origin/*' '+refs/tags/*:refs/tags/*'
  git -C "${MYSTIC_DIR}" fetch --no-tags origin "${MYSTIC_REF}" || true
  git -C "${MYSTIC_DIR}" -c advice.detachedHead=false checkout -q "${MYSTIC_REF}"
fi

commit="$(git -C "${MYSTIC_DIR}" rev-parse HEAD)"
echo "MysticGSI commit: ${commit}"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "commit=${commit}" >> "${GITHUB_OUTPUT}"
fi
