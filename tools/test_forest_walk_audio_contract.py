"""Guards the Forest Walk file-music contract.

Forest Walk music is authored as assets/audio/forest_walk.wav or .mp3 and
converted at build time; the application packages must not depend on the SDK
MIDI/song synthesis anymore, and the generated device PCM must stay out of
version control.
"""

import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
FOREST_WALK = REPO_ROOT / "src" / "forest_walk"
RUNTIME_WASM = REPO_ROOT / "src" / "runtime_wasm"
ASSETS = REPO_ROOT / "assets" / "audio"
SOURCES = ("wav", "mp3")


def package_sources(package: Path):
    return sorted(path for path in package.glob("*.mbt"))


class ForestWalkAudioContractTests(unittest.TestCase):
    def test_forest_walk_has_no_midi_song_dependency(self):
        for path in package_sources(FOREST_WALK):
            for line in path.read_text().splitlines():
                self.assertNotIn(
                    "@music.",
                    line,
                    f"{path.name} still references SDK music synthesis",
                )
                self.assertNotIn(
                    "ai-passport/music",
                    line,
                    f"{path.name} still imports the SDK music package",
                )
        pkg = (FOREST_WALK / "moon.pkg").read_text()
        self.assertNotIn("ai-passport/music", pkg)
        self.assertNotIn("ai-passport/audio", pkg)

    def test_wasm_runtime_has_no_sdk_player(self):
        # The wasm entry package (the only browser-side runtime since the
        # legacy JS preview was removed) must not pull in the SDK MIDI/song
        # synthesis or PCM player: Forest Walk plays the canonical
        # normalized PCM asset through the Web Host.
        for path in package_sources(RUNTIME_WASM):
            for line in path.read_text().splitlines():
                self.assertNotIn(
                    "@music.",
                    line,
                    f"{path.name} still references SDK music synthesis",
                )
                self.assertNotIn(
                    "@audio.",
                    line,
                    f"{path.name} still references the SDK PCM player",
                )
        pkg = (RUNTIME_WASM / "moon.pkg").read_text()
        self.assertNotIn("ai-passport/music", pkg)
        self.assertNotIn("ai-passport/audio", pkg)

    def test_exactly_one_authored_music_asset(self):
        present = [
            kind for kind in SOURCES if (ASSETS / f"forest_walk.{kind}").is_file()
        ]
        self.assertEqual(
            len(present),
            1,
            f"expected exactly one authored music asset, found: {present}",
        )

    def test_generated_device_pcm_is_not_tracked(self):
        gitignore = (REPO_ROOT / ".gitignore").read_text()
        self.assertIn("/device/esp32c3/generated/", gitignore)
        tracked = subprocess_run(
            ["git", "ls-files", "device/esp32c3/generated/"], cwd=REPO_ROOT
        )
        self.assertEqual(
            tracked,
            "",
            "generated device audio must not be committed",
        )

    def test_canonical_passport_workspace_is_not_tracked(self):
        gitignore = (REPO_ROOT / ".gitignore").read_text()
        self.assertIn("/.passport/", gitignore)
        tracked = subprocess_run(
            ["git", "ls-files", ".passport/"], cwd=REPO_ROOT
        )
        self.assertEqual(
            tracked,
            "",
            "the canonical PCM and web bundle must not be committed",
        )

    def test_committed_audio_meta_is_generated_deterministically(self):
        meta = REPO_ROOT / "src" / "forest_walk" / "generated" / "audio_meta.mbt"
        self.assertTrue(meta.is_file(), "audio_meta.mbt must be committed")
        canonical = REPO_ROOT / ".passport" / "assets" / "forest_walk.pcm"
        if not canonical.is_file():
            self.skipTest("canonical PCM not built yet")
        samples = canonical.stat().st_size // 2
        duration = samples * 1_000_000 // 16000
        text = meta.read_text()
        self.assertIn(
            f"pub const AUDIO_TOTAL_SAMPLES : Int = {samples}", text
        )
        self.assertIn(
            f"pub const AUDIO_DURATION_US : Int64 = {duration}L", text
        )


def subprocess_run(args, cwd):
    import subprocess

    return subprocess.run(
        args, cwd=cwd, capture_output=True, text=True, check=True
    ).stdout


if __name__ == "__main__":
    unittest.main()
