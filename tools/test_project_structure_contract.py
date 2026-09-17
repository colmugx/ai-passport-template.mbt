import json
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SDK_DEPENDENCY = "colmugx/ai-passport@0.0.4"
PASSPORT_CLI = "colmugx/ai-passport/cmd/passport@0.0.4"


class ProjectStructureContractTests(unittest.TestCase):
    def test_moon_mod_uses_current_sdk(self):
        text = (REPO_ROOT / "moon.mod").read_text()
        self.assertIn(f'"{SDK_DEPENDENCY}",', text)

    def test_host_dependency_is_project_provided(self):
        dep = REPO_ROOT / "external" / "folotoy-ai-passport"
        self.assertTrue((dep / "components" / "bsp" / "include").is_dir())
        contract = json.loads((REPO_ROOT / "passport.json").read_text())
        self.assertEqual(
            contract["hostDependencies"]["folotoy-ai-passport"]["path"],
            "external/folotoy-ai-passport",
        )

    def test_device_entry_is_thin_native_foreign_library(self):
        package = REPO_ROOT / "src" / "runtime_native" / "moon.pkg"
        text = package.read_text()
        self.assertIn('supported_targets = "native"', text)
        self.assertIn('pkgtype(kind: "foreign_library")', text)
        self.assertNotIn("link:", text)

        runtime = (REPO_ROOT / "src" / "runtime_native" / "runtime.mbt").read_text()
        for export in (
            "ai_passport_mbt_probe",
            "ai_passport_mbt_app_init",
            "ai_passport_mbt_app_update",
            "ai_passport_mbt_app_draw",
            "ai_passport_mbt_app_present",
            "ai_passport_mbt_input_press",
            "ai_passport_mbt_audio_volume",
            "ai_passport_mbt_audio_muted",
        ):
            self.assertIn(f'"{export}"', runtime)
        self.assertNotIn("extern", runtime)

    def test_passport_contract(self):
        contract = json.loads((REPO_ROOT / "passport.json").read_text())
        self.assertEqual(contract["entry"], "runtime_wasm")
        self.assertEqual(contract["deviceEntry"], "runtime_native")
        looping = [a for a in contract["assets"] if a.get("pcmLoop") is True]
        self.assertEqual(
            looping,
            [
                {
                    "source": ".passport/assets/forest_walk.pcm",
                    "bundlePath": "assets/forest_walk.pcm",
                    "pcmLoop": True,
                }
            ],
        )

    def test_dispatcher_uses_current_published_cli(self):
        text = (REPO_ROOT / "tools" / "passport.mbtx").read_text()
        self.assertIn(PASSPORT_CLI, text)
        self.assertIn('"moonx"', text)
        self.assertIn('"folotoy-ai-passport"', text)

    def test_browser_integration_targets_sdk_entry(self):
        text = (REPO_ROOT / "tools" / "web-integration" / "run.mjs").read_text()
        self.assertIn("index.html?pcm=./assets/forest_walk.pcm&pcmLoop=1", text)


if __name__ == "__main__":
    unittest.main()
