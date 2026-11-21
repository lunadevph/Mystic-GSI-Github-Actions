#!/usr/bin/env bash
# Prepare a build host for an AOSP / TrebleDroid build.
# Safe to re-run: every destructive action is limited to CI tooling we do not need.
set -euo pipefail

echo "::group::Environment"
uname -a
echo "CPUs: $(nproc --all)"
echo "Memory: $(free -h | awk '/^Mem:/ {print $2}')"
echo "Disk:"
df -h /
echo "::endgroup::"

echo "::group::Free disk space"
# GitHub-hosted runners ship with several GB of toolchains an AOSP build never uses.
for path in \
  /usr/share/dotnet \
  /usr/local/lib/android \
  /usr/local/share/boost \
  /opt/ghc \
  /opt/hostedtoolcache; do
  sudo rm -rf "${path}" || true
done
sudo apt-get clean || true
docker system prune -af || true
df -h /
echo "::endgroup::"

echo "::group::Install dependencies"
sudo apt-get update -qq

# Core packages: required for repo + AOSP on Ubuntu 20.04/22.04/24.04.
sudo apt-get install -y --no-install-recommends \
  bc bison build-essential ccache curl flex g++-multilib gcc-multilib \
  git git-lfs gnupg gperf imagemagick lib32z1-dev libelf-dev liblz4-tool \
  libncurses-dev libssl-dev libxml2 libxml2-utils lzop pngcrush rsync \
  schedtool squashfs-tools xsltproc zip zlib1g-dev xz-utils unzip python3

# Optional packages: names drift between Ubuntu releases, so don't fail the job.
sudo apt-get install -y --no-install-recommends \
  lib32ncurses-dev lib32readline-dev libsdl1.2-dev openjdk-17-jdk-headless \
  || echo "::warning::Some optional build packages were unavailable on this image"
echo "::endgroup::"

echo "::group::Install repo"
mkdir -p "${HOME}/bin"
curl -fsSL https://storage.googleapis.com/git-repo-downloads/repo -o "${HOME}/bin/repo"
chmod a+x "${HOME}/bin/repo"
echo "${HOME}/bin" >> "${GITHUB_PATH:-/dev/null}"
export PATH="${HOME}/bin:${PATH}"
repo --version
echo "::endgroup::"

echo "::group::Configure tooling"
git config --global user.name "Mystic GSI Bot"
git config --global user.email "mystic-gsi@users.noreply.github.com"
git config --global color.ui false
git lfs install --skip-repo || true

if command -v ccache >/dev/null 2>&1; then
  ccache -M "${CCACHE_MAXSIZE:-5G}"
  ccache -z
fi
echo "::endgroup::"

echo "Runner is ready."
