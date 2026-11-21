#!/usr/bin/env bash
# Free disk space on GitHub-hosted runners before downloading large firmware.
set -euo pipefail

echo "::group::Disk before cleanup"
df -h /
echo "::endgroup::"

# Preinstalled toolchains a firmware conversion never uses.
for path in \
  /usr/share/dotnet \
  /usr/local/lib/android \
  /opt/ghc \
  /opt/hostedtoolcache \
  /usr/local/share/boost \
  /usr/share/swift; do
  sudo rm -rf "${path}" 2>/dev/null || true
done

sudo apt-get clean 2>/dev/null || true
docker system prune -af 2>/dev/null || true

echo "::group::Disk after cleanup"
df -h /
available="$(df -PB1 / 2>/dev/null | awk 'NR==2 {print $4}')"
if [ -n "${available}" ] && [ "${available}" -lt 26843545600 ]; then
  echo "::warning::Less than 25 GiB free after cleanup; large firmware may run out of disk"
fi
echo "::endgroup::"
