#!/usr/bin/env python3
"""Verify that Web and device consume the canonical PCM bytes."""

import hashlib
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
CANONICAL = REPO_ROOT / ".passport" / "assets" / "forest_walk.pcm"
WEB_COPY = REPO_ROOT / ".passport" / "web" / "assets" / "forest_walk.pcm"
DEVICE_COPY = REPO_ROOT / ".passport" / "folotoy-ai-passport" / "passport_music.pcm"


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
        fail(f"canonical PCM missing: {CANONICAL}")
    canonical_hash = sha256(CANONICAL)
    size = CANONICAL.stat().st_size
    if size == 0 or size % 2 != 0:
        fail(f"canonical PCM must be non-empty and even-length, got {size} bytes")

    if not WEB_COPY.is_file():
        fail(f"web PCM missing: {WEB_COPY}")
    if sha256(WEB_COPY) != canonical_hash:
        fail("web PCM differs from the canonical artifact")

    if DEVICE_COPY.is_file() and sha256(DEVICE_COPY) != canonical_hash:
        fail("device PCM differs from the canonical artifact")

    print(f"PASS: PCM identity {canonical_hash} ({size} bytes)")


if __name__ == "__main__":
    main()
