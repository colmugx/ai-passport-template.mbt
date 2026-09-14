#!/usr/bin/env bash
set -euo pipefail

device_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/esp32c3" && pwd)"
if [[ -z "${IDF_PATH:-}" ]]; then
    echo "Source ESP-IDF 5.5.3 export.sh before building" >&2
    exit 1
fi
idf_version="$(idf.py --version)"
if [[ "$idf_version" != "ESP-IDF v5.5.3" ]]; then
    echo "Expected ESP-IDF v5.5.3, got: $idf_version" >&2
    exit 1
fi
export MOON_HOME="${MOON_HOME:-$HOME/.moon}"
export IDF_TARGET=esp32c3
"$device_root/generate_moonbit_c.sh"
cd "$device_root"
idf.py build
