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
# Materialize the effective sdkconfig (created from sdkconfig.defaults when
# missing) before verifying the tick-rate baseline; an sdkconfig generated
# before the baseline was added keeps its old values until regenerated.
idf.py reconfigure
if ! grep -qx 'CONFIG_FREERTOS_HZ=1000' "$device_root/sdkconfig"; then
    echo "Effective sdkconfig does not contain CONFIG_FREERTOS_HZ=1000," >&2
    echo "the AI Passport FreeRTOS timing baseline. Found instead:" >&2
    grep '^CONFIG_FREERTOS_HZ=' "$device_root/sdkconfig" >&2 || true
    echo "The existing sdkconfig predates this baseline and was not regenerated." >&2
    echo "Regenerate it with: rm $device_root/sdkconfig && ./device/build.sh" >&2
    exit 1
fi
idf.py build
