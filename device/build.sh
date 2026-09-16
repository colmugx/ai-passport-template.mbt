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
# ONE canonical normalization for a device build: the unified assets command
# regenerates graphics, normalizes the authored WAV/MP3 into
# .passport/assets/forest_walk.pcm (embedded by the music_stream component at
# configure time) and rewrites src/forest_walk/generated/audio_meta.mbt. It
# MUST run before the MoonBit C capture, or a changed authored track could
# pair old duration metadata with new PCM bytes in one firmware.
(cd "$repo_root" && moon run tools/passport.mbtx assets)
"$device_root/generate_moonbit_c.sh"
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
