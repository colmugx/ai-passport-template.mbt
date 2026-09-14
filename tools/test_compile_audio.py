import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).with_name("compile_audio.py")
REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(SCRIPT.parent))
import compile_audio


def make_tone(path: Path, seconds: float) -> None:
    """Authors a small test asset with ffmpeg itself."""
    subprocess.run(
        [
            "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
            "-f", "lavfi", "-i", f"sine=frequency=440:duration={seconds}",
            "-ar", "44100", "-ac", "2",
            "-c:a", "pcm_s16le" if path.suffix == ".wav" else "libmp3lame",
            str(path),
        ],
        check=True,
    )


class CompileAudioTests(unittest.TestCase):
    def setUp(self):
        if shutil.which("ffmpeg") is None:
            self.skipTest("ffmpeg is not installed")
        self.root = Path(tempfile.mkdtemp())
        self.assets = self.root / "assets"
        self.assets.mkdir()
        self.output = self.root / "out" / "music.pcm"

    def run_tool(self, *extra_args):
        return subprocess.run(
            [sys.executable, str(SCRIPT),
             "--assets-dir", str(self.assets),
             "--output", str(self.output),
             *extra_args],
            capture_output=True,
            text=True,
        )

    def test_wav_source_is_selected_and_converted(self):
        make_tone(self.assets / "forest_walk.wav", 1.0)
        result = self.run_tool()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("forest_walk.wav", result.stdout)
        size = self.output.stat().st_size
        self.assertEqual(size % 2, 0)
        self.assertAlmostEqual(size / 32000, 1.0, delta=0.1)
        self.assertIn("PCM16 little-endian / mono / 16000 Hz", result.stdout)

    def test_mp3_source_is_selected_and_converted(self):
        make_tone(self.assets / "forest_walk.mp3", 1.0)
        result = self.run_tool()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("forest_walk.mp3", result.stdout)
        self.assertAlmostEqual(
            self.output.stat().st_size / 32000, 1.0, delta=0.1
        )

    def test_duplicate_wav_and_mp3_is_rejected(self):
        make_tone(self.assets / "forest_walk.wav", 1.0)
        make_tone(self.assets / "forest_walk.mp3", 1.0)
        result = self.run_tool()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("ambiguous", result.stderr)
        self.assertFalse(self.output.exists())

    def test_duplicate_resolves_with_explicit_source_policy(self):
        make_tone(self.assets / "forest_walk.wav", 1.0)
        make_tone(self.assets / "forest_walk.mp3", 1.0)
        result = self.run_tool("--source", "mp3")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("forest_walk.mp3", result.stdout)

    def test_missing_source_is_rejected(self):
        result = self.run_tool()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("no authored music", result.stderr)

    def test_converted_output_decodes_as_target_format(self):
        make_tone(self.assets / "forest_walk.wav", 1.0)
        self.run_tool()
        probe = subprocess.run(
            [
                "ffprobe", "-v", "error", "-f", "s16le", "-ar", "16000",
                "-ch_layout", "mono", "-show_entries",
                "stream=codec_name,sample_rate,channels", "-of", "json",
                str(self.output),
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        stream = json.loads(probe.stdout)["streams"][0]
        self.assertEqual(stream["codec_name"], "pcm_s16le")
        self.assertEqual(stream["sample_rate"], "16000")
        self.assertEqual(stream["channels"], 1)

    def test_conversion_is_deterministic(self):
        make_tone(self.assets / "forest_walk.wav", 1.0)
        self.run_tool()
        first = self.output.read_bytes()
        self.run_tool()
        self.assertEqual(first, self.output.read_bytes())

    def test_flash_budget_is_enforced(self):
        make_tone(self.assets / "forest_walk.wav", 1.0)
        result = self.run_tool("--max-bytes", "16000")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("budget", result.stderr)

    def test_pcm_budget_fits_inside_factory_app_partition(self):
        # The PCM is embedded in the factory app image, so the tool's budget
        # must be smaller than the partition partitions.csv actually grants,
        # with at least 1 MiB still reserved for the firmware itself.
        sizes = {}
        table = REPO_ROOT / "device" / "esp32c3" / "partitions.csv"
        for line in table.read_text().splitlines():
            line = line.split("#", 1)[0].strip()
            if not line:
                continue
            fields = [field.strip() for field in line.split(",")]
            sizes[fields[0]] = int(fields[4], 0)
        factory = sizes["factory"]
        self.assertLess(compile_audio.MAX_PCM_BYTES, factory)
        self.assertGreaterEqual(
            factory - compile_audio.MAX_PCM_BYTES, 1024 * 1024
        )

    def test_default_budget_rejects_oversized_track(self):
        # 90 s at 32,000 bytes/s = 2,880,000 bytes: over the 0x280000
        # default ceiling, so the tool must refuse without any --max-bytes.
        make_tone(self.assets / "forest_walk.wav", 90.0)
        result = self.run_tool()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("budget", result.stderr)
        self.assertIn(str(compile_audio.MAX_PCM_BYTES), result.stderr)

    def test_committed_authored_asset_still_converts(self):
        # The real repository asset must keep converting cleanly.
        result = subprocess.run(
            [sys.executable, str(SCRIPT)],
            capture_output=True,
            text=True,
            cwd=REPO_ROOT,
        )
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
