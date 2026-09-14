#!/usr/bin/env bash
set -euo pipefail

device_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$device_root/../.." && pwd)"
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
rm -rf "$repo_root/_build/native"
mkdir -p "$capture_dir"
export MOON_CC_CAPTURE_DIR="$capture_dir"
export MOONBIT_NEW_NATIVE=0

# src/device/moon.pkg deliberately ships no capture cc: normal root native
# builds must use the standard Moon toolchain. The capture applies the link-cc
# override only for this invocation and restores the file afterwards. Moon
# derives the archiver from the link cc's directory, so the temporary cc lives
# in a scratch directory that also links the real system archiver; no fake
# tools/ar shim is involved.
pkg_path="$repo_root/src/device/moon.pkg"
cc_scratch="$(mktemp -d)"
pkg_backup="$cc_scratch/moon.pkg.orig"
cleanup() {
    if [[ -e "$pkg_backup" ]]; then
        mv "$pkg_backup" "$pkg_path"
    fi
    rm -rf "$cc_scratch"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

system_ar="$(command -v ar || true)"
if [[ -z "$system_ar" ]]; then
    echo "System archiver 'ar' not found on PATH" >&2
    exit 1
fi
ln -s "$repo_root/tools/moon_cc_capture.py" "$cc_scratch/moon_cc_capture.py"
ln -s "$system_ar" "$cc_scratch/ar"
cp "$pkg_path" "$pkg_backup"
scratch_cc="$cc_scratch/moon_cc_capture.py"
python3 - "$pkg_path" "$scratch_cc" <<'EOF'
import sys
from pathlib import Path

pkg_path, scratch_cc = sys.argv[1], sys.argv[2]
anchor = '  "native-stub": [ "host_display_stub.c" ],\n'
override = f'  link: {{ "native": {{ "cc": "{scratch_cc}" }} }},\n'
pkg = Path(pkg_path)
text = pkg.read_text()
if "link:" in text:
    sys.exit(
        "moon.pkg unexpectedly already contains a link override; "
        "restore it with: git checkout -- src/device/moon.pkg"
    )
if anchor not in text:
    sys.exit("moon.pkg anchor for the device capture cc injection was not found")
pkg.write_text(text.replace(anchor, anchor + override, 1))
EOF
if ! grep -qF -- "\"$scratch_cc\"" "$pkg_path"; then
    echo "Failed to inject the device capture cc into $pkg_path" >&2
    exit 1
fi

(
    cd "$repo_root"
    moon build src/device --target native --release
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
