#!/usr/bin/env bash
set -euo pipefail

device_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/esp32c3" && pwd)"
repo_root="$(cd "$device_root/../.." && pwd)"
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
# Normalize the authored WAV/MP3 into the flash-resident device PCM; CMake
# embeds it, so it must exist before configure time.
python3 "$repo_root/tools/compile_audio.py"
cd "$device_root"
# Materialize the effective sdkconfig (created from sdkconfig.defaults when
# missing) before verifying the baselines; an sdkconfig generated before a
# baseline was added keeps its old values until regenerated.
idf.py reconfigure
stale=0
grep -qx 'CONFIG_FREERTOS_HZ=1000' "$device_root/sdkconfig" || stale=1
grep -qx 'CONFIG_PARTITION_TABLE_CUSTOM=y' "$device_root/sdkconfig" || stale=1
grep -qx 'CONFIG_PARTITION_TABLE_CUSTOM_FILENAME="partitions.csv"' \
    "$device_root/sdkconfig" || stale=1
if [[ "$stale" != 0 ]]; then
    echo "Effective sdkconfig misses the AI Passport baselines" \
        "(CONFIG_FREERTOS_HZ=1000, CONFIG_PARTITION_TABLE_CUSTOM=y," \
        'CONFIG_PARTITION_TABLE_CUSTOM_FILENAME="partitions.csv").' >&2
    grep -E '^CONFIG_FREERTOS_HZ=|^CONFIG_PARTITION_TABLE_CUSTOM' \
        "$device_root/sdkconfig" >&2 || true
    echo "The existing sdkconfig predates these defaults and was not regenerated." >&2
    echo "Regenerate it with: rm $device_root/sdkconfig && ./device/build.sh" >&2
    exit 1
fi
idf.py build
