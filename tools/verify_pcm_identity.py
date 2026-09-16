#!/usr/bin/env python3
"""Prove the PCM artifact identity (R2A contract; adapted for R4A2).

Exactly one normalization invocation per build workflow writes the ONE
canonical artifact:

    .passport/assets/forest_walk.pcm

Both consumers must resolve to those exact bytes:

  * web bundle:    .passport/web/assets/forest_walk.pcm  (byte-for-byte copy)
  * device build:  .passport/folotoy-ai-passport/passport_music.pcm — the
                   SDK passport CLI materializes the firmware's music file
                   from the contract's pcmLoop asset (byte-for-byte copy)

The device workspace copy exists only after a device build, so it is
checked whenever present and clearly skipped otherwise (CI never runs
ESP-IDF).

This script fails (exit 1) on any mismatch. Run it after
`moon run tools/passport.mbtx build web`.
"""

import hashlib
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
CANONICAL = REPO_ROOT / ".passport" / "assets" / "forest_walk.pcm"
WEB_COPY = REPO_ROOT / ".passport" / "web" / "assets" / "forest_walk.pcm"
DEVICE_COPY = (
    REPO_ROOT / ".passport" / "folotoy-ai-passport" / "passport_music.pcm"
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

    if DEVICE_COPY.is_file():
        device_hash = sha256(DEVICE_COPY)
        print(f"device:   {DEVICE_COPY.relative_to(REPO_ROOT)}")
        print(f"  sha256: {device_hash}")
        if device_hash != canonical_hash:
            fail("device embedded-input PCM differs from the canonical artifact")
    else:
        print(
            "device:   workspace not built yet "
            f"({DEVICE_COPY.relative_to(REPO_ROOT)} absent; "
            "run: moon run tools/passport.mbtx build device)"
        )

    print(
        "PASS: web PCM "
        + ("== device embedded-input PCM " if DEVICE_COPY.is_file() else "")
        + f"== canonical artifact (sha256 {canonical_hash})"
    )


if __name__ == "__main__":
    main()
