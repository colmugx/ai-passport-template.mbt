#!/usr/bin/env bash
set -euo pipefail
device_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/esp32c3" && pwd)"
cd "$device_root"
idf.py monitor "$@"
