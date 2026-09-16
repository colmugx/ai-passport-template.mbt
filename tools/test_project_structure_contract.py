"""Guards the R4A2 single-implementation, SDK-owned-host architecture.

There is exactly ONE application implementation: the shared MoonBit App
executed by the SDK Web Host through src/runtime_wasm on the web side and
by the SDK device backend through the thin src/runtime_native entry on the
device side. The template owns no Host implementation: the legacy template
device tree (device/, src/device, the BSP submodule) is gone, and the
legacy JS browser runtime (src/web, the root web/ preview shell, dev.sh)
is gone; the SDK's own index.html with generic URL parameters is the only
web entry.
"""

import json
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

SDK_DEPENDENCY = "colmugx/ai-passport@0.0.3"
DEV_URL_QUERY = "index.html?pcm=./assets/forest_walk.pcm&pcmLoop=1"


class ProjectStructureContractTests(unittest.TestCase):
    def test_legacy_browser_runtime_is_gone(self):
        self.assertFalse(
            (REPO_ROOT / "src" / "web").exists(),
            "src/web must not exist: the shared MoonBit App + SDK Web Host "
            "is the only browser implementation",
        )

    def test_legacy_root_web_preview_is_gone(self):
        self.assertFalse(
            (REPO_ROOT / "web").exists(),
            "the root web/ preview shell must not exist",
        )

    def test_legacy_dev_sh_is_gone(self):
        self.assertFalse(
            (REPO_ROOT / "dev.sh").exists(),
            "dev.sh belonged to the deleted JS preview architecture",
        )

    def test_moon_mod_pins_published_sdk(self):
        text = (REPO_ROOT / "moon.mod").read_text()
        self.assertIn(
            f'"{SDK_DEPENDENCY}",',
            text,
            f"moon.mod must depend on the published SDK ({SDK_DEPENDENCY})",
        )
        for older in ("colmugx/ai-passport@0.0.2", "colmugx/ai-passport@0.0.1"):
            self.assertNotIn(older, text)

    def test_no_moon_work(self):
        self.assertFalse(
            (REPO_ROOT / "moon.work").exists(),
            "moon.work would override the published dependency resolution",
        )

    def test_host_implementations_are_sdk_owned(self):
        for gone in (
            "device",
            "src/device",
            "external",
            ".gitmodules",
            "tools/moon_cc_capture.py",
        ):
            self.assertFalse(
                (REPO_ROOT / gone).exists(),
                f"{gone} must not exist: Host implementation is SDK-owned "
                "(hosts live in the SDK's hosts/folotoy-ai-passport)",
            )

    def test_device_entry_is_a_thin_native_foreign_library(self):
        pkg = REPO_ROOT / "src" / "runtime_native" / "moon.pkg"
        self.assertTrue(
            pkg.is_file(),
            "src/runtime_native/moon.pkg must exist: the thin device entry",
        )
        text = pkg.read_text()
        self.assertIn('supported_targets = "native"', text)
        self.assertIn('pkgtype(kind: "foreign_library")', text)
        # The SDK passport CLI injects the capture link override for exactly
        # one build; the committed package must carry no link override.
        self.assertNotIn(
            "link:",
            text,
            "the device entry must not declare a link override (the SDK "
            "CLI injects the capture cc per build)",
        )
        self.assertNotIn(
            "native-stub",
            text,
            "the thin entry owns no C stubs (bridge coverage lives in the "
            "SDK)",
        )
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
        self.assertNotIn(
            "extern",
            runtime,
            "the thin entry must not declare its own FFI (SDK hostabi owns "
            "the externs)",
        )

    def test_passport_json_contract_shape(self):
        contract = json.loads((REPO_ROOT / "passport.json").read_text())
        self.assertEqual(contract["entry"], "runtime_wasm")
        self.assertEqual(contract["deviceEntry"], "runtime_native")
        looping = [
            asset
            for asset in contract.get("assets", [])
            if asset.get("pcmLoop") is True
        ]
        self.assertEqual(len(looping), 1)
        self.assertEqual(
            looping[0]["source"], ".passport/assets/forest_walk.pcm"
        )
        self.assertEqual(looping[0]["bundlePath"], "assets/forest_walk.pcm")

    def test_dispatcher_delegates_to_the_sdk_cli(self):
        text = (REPO_ROOT / "tools" / "passport.mbtx").read_text()
        self.assertIn("src/cmd/passport", text)
        self.assertIn("folotoy-ai-passport", text)
        self.assertFalse(
            (REPO_ROOT / "tools" / "build.mbtx").exists(),
            "tools/build.mbtx duplicated the SDK CLI web build and must "
            "stay deleted",
        )

    def test_dev_mbtx_targets_sdk_index_html_with_host_params(self):
        text = (REPO_ROOT / "tools" / "dev.mbtx").read_text()
        self.assertIn(
            DEV_URL_QUERY,
            text,
            "the dev URL must be the SDK index.html with generic "
            "?pcm= / ?pcmLoop= host configuration",
        )
        self.assertNotIn("app.html", text)

    def test_web_integration_still_exists_and_boots_the_sdk_page(self):
        runner = REPO_ROOT / "tools" / "web-integration" / "run.mjs"
        self.assertTrue(
            runner.is_file(),
            "tools/web-integration/run.mjs must keep testing the real "
            "browser boot path",
        )
        text = runner.read_text()
        self.assertIn(DEV_URL_QUERY, text)
        self.assertNotIn(
            'require("passport-host.js")',
            text,
            "the integration test must not import the SDK host manually",
        )
        self.assertIn(
            "app.html",
            text,
            "the integration test must assert app.html is absent",
        )


if __name__ == "__main__":
    unittest.main()
