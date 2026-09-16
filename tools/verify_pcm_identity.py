#!/usr/bin/env python3
"""Prove the PCM artifact identity (R2A contract, task items 8 and 24).

Exactly one normalization invocation per build workflow writes the ONE
canonical artifact:

    .passport/assets/forest_walk.pcm

Both consumers must resolve to those exact bytes:

  * web bundle:  .passport/web/assets/forest_walk.pcm  (byte-for-byte copy)
  * device:      the ESP-IDF music_stream component embeds the canonical
                 file directly (verified here by pinning the CMake path,
                 since CI does not run ESP-IDF)

This script fails (exit 1) on any mismatch. Run it after
`moon run tools/passport.mbtx build web`.
"""

import hashlib
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
CANONICAL = REPO_ROOT / ".passport" / "assets" / "forest_walk.pcm"
WEB_COPY = REPO_ROOT / ".passport" / "web" / "assets" / "forest_walk.pcm"
DEVICE_CMAKE = (
    REPO_ROOT
    / "device"
    / "esp32c3"
    / "components"
    / "music_stream"
    / "CMakeLists.txt"
)


def fail(message: str):
    print(f"verify_pcm_identity: FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> None:
    if not CANONICAL.is_file():
        fail(
            f"canonical PCM missing: {CANONICAL}; "
            "run: moon run tools/passport.mbtx assets"
        )
    canonical_hash = sha256(CANONICAL)
    size = CANONICAL.stat().st_size
    if size == 0 or size % 2 != 0:
        fail(f"canonical PCM must be non-empty and even-length, got {size} bytes")
    print(f"canonical: {CANONICAL.relative_to(REPO_ROOT)}")
    print(f"  sha256: {canonical_hash}")
    print(f"  size:   {size} bytes ({size // 2} samples)")

    if not WEB_COPY.is_file():
        fail(
            f"web bundle PCM missing: {WEB_COPY}; "
            "run: moon run tools/passport.mbtx build web"
        )
    web_hash = sha256(WEB_COPY)
    print(f"web:      {WEB_COPY.relative_to(REPO_ROOT)}")
    print(f"  sha256: {web_hash}")
    if web_hash != canonical_hash:
        fail("web served PCM differs from the canonical artifact")

    cmake = DEVICE_CMAKE.read_text()
    match = re.search(
        r'set\(MUSIC_PCM_FILE "\$\{REPO_ROOT\}/([^"]+)"\)', cmake
    )
    if not match:
        fail(f"cannot find MUSIC_PCM_FILE in {DEVICE_CMAKE}")
    device_path = match.group(1)
    expected = ".passport/assets/forest_walk.pcm"
    print(f"device:   {DEVICE_CMAKE.relative_to(REPO_ROOT)}")
    print(f"  embeds: {device_path}")
    if device_path != expected:
        fail(
            f"device embeds {device_path}, not the canonical {expected}; "
            "the firmware would flash different bytes than the web serves"
        )
    embedded = REPO_ROOT / device_path
    if not embedded.is_file():
        fail(f"device input PCM missing: {embedded}")
    # REPO_ROOT-relative path resolves to the canonical file itself; the
    # byte identity is the canonical hash checked above.
    embedded_hash = sha256(embedded)
    if embedded_hash != canonical_hash:
        fail("device embedded-input PCM differs from the canonical artifact")

    print(
        "PASS: web PCM == device embedded-input PCM == canonical artifact "
        f"(sha256 {canonical_hash})"
    )


if __name__ == "__main__":
    main()
