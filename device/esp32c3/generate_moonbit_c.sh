#!/usr/bin/env bash
set -euo pipefail

device_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$device_root/../.." && pwd)"
device_module="$device_root/moonbit"
moon_home="${MOON_HOME:-$HOME/.moon}"
export MOON_HOME="$moon_home"

if ! command -v moon >/dev/null 2>&1; then
    echo "MoonBit moon command is unavailable" >&2
    exit 1
fi
version_output="$(moon version)"
moon_version="${version_output%%$'\n'*}"
if [[ "$moon_version" != "moon 0.1.20260904 (94521db 2026-09-04)" ]]; then
    echo "Expected MoonBit 0.1.20260904 (94521db), got: $moon_version" >&2
    exit 1
fi
(
    cd "$moon_home"
    shasum -a 256 -c "$device_root/moonbit-runtime.sha256"
)

capture_dir="$device_root/generated/moonbit"
rm -rf "$capture_dir"
rm -rf "$device_module/_build"
mkdir -p "$capture_dir"
export MOON_CC_CAPTURE_DIR="$capture_dir"
export PATH="$repo_root/tools:$PATH"
export MOONBIT_NEW_NATIVE=0
(
    cd "$device_module"
    moon build --target native --release
)

manifest="$capture_dir/sources.txt"
if [[ ! -s "$manifest" ]]; then
    echo "Moon C capture produced no source manifest: $manifest" >&2
    exit 1
fi
while IFS= read -r source; do
    if [[ ! -s "$capture_dir/$source" ]]; then
        echo "Captured C source missing or empty: $source" >&2
        exit 1
    fi
done < "$manifest"
echo "Captured MoonBit C with $moon_version:"
cat "$manifest"
