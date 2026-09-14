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
WEB = REPO_ROOT / "src" / "web"
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

    def test_browser_runtime_has_no_sdk_player(self):
        for path in package_sources(WEB):
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
        pkg = (WEB / "moon.pkg").read_text()
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


def subprocess_run(args, cwd):
    import subprocess

    return subprocess.run(
        args, cwd=cwd, capture_output=True, text=True, check=True
    ).stdout


if __name__ == "__main__":
    unittest.main()
