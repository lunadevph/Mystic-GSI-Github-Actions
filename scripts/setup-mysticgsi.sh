#!/usr/bin/env bash
# Run MysticGSI's own host setup (apt packages + .venv + requirements).
set -euo pipefail

MYSTIC_DIR="${MYSTIC_DIR:-$(pwd)/mysticgsi}"

if [ ! -f "${MYSTIC_DIR}/setup_host.py" ]; then
  echo "error: ${MYSTIC_DIR}/setup_host.py not found; run fetch-mysticgsi.sh first" >&2
  exit 1
fi

cd "${MYSTIC_DIR}"

python3 --version
echo "Running MysticGSI setup_host.py"
python3 setup_host.py

venv_python="${MYSTIC_DIR}/.venv/bin/python"
if [ ! -x "${venv_python}" ]; then
  echo "error: ${venv_python} was not created" >&2
  exit 1
fi

"${venv_python}" - <<'PY'
import brotli  # noqa: F401
import lz4  # noqa: F401
import py7zr  # noqa: F401
import requests  # noqa: F401
import zstandard  # noqa: F401
from Crypto.Cipher import AES  # noqa: F401
from google.protobuf import __version__ as protobuf_version

print(f"Python dependencies OK (protobuf {protobuf_version})")
PY

echo "MysticGSI environment ready."
