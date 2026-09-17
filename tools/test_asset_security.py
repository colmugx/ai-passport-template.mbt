import os
import shutil
import struct
import subprocess
import tempfile
import unittest
import zlib
from pathlib import Path

import compile_audio
import png_decode


def chunk(kind: bytes, payload: bytes) -> bytes:
    return (
        struct.pack(">I", len(payload))
        + kind
        + payload
        + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)
    )


def png(width: int, height: int, raw: bytes) -> bytes:
    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    return (
        png_decode.PNG_SIGNATURE
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(raw))
        + chunk(b"IEND", b"")
    )


class AssetSecurityTests(unittest.TestCase):
    def test_png_rejects_excessive_dimensions(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "huge.png"
            path.write_bytes(png(100_000, 100_000, b""))
            with self.assertRaisesRegex(ValueError, "exceed limits"):
                png_decode.read_rgba_png(path)

    def test_png_rejects_decompression_overrun(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "bomb.png"
            path.write_bytes(png(1, 1, b"\x00" * 4096))
            with self.assertRaisesRegex(ValueError, "exceeds expected size"):
                png_decode.read_rgba_png(path)

    def test_audio_budget_failure_preserves_previous_output(self):
        if shutil.which("ffmpeg") is None:
            self.skipTest("ffmpeg is not installed")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "tone.wav"
            output = root / "music.pcm"
            subprocess.run(
                [
                    "ffmpeg",
                    "-y",
                    "-hide_banner",
                    "-loglevel",
                    "error",
                    "-f",
                    "lavfi",
                    "-i",
                    "sine=frequency=440:duration=0.1",
                    str(source),
                ],
                check=True,
            )
            previous = os.urandom(16)
            output.write_bytes(previous)
            with self.assertRaises(SystemExit):
                compile_audio.convert(source, output, max_bytes=8)
            self.assertEqual(output.read_bytes(), previous)


if __name__ == "__main__":
    unittest.main()
