"""Guards the R2C single-implementation web architecture.

After R2C there is exactly ONE application implementation: the shared
MoonBit App executed by the published SDK Web Host through
src/runtime_wasm on the web side and src/device (ESP-IDF) on the device
side. The legacy JS browser runtime (src/web, the root web/ preview shell,
dev.sh) and the temporary template-generated app.html bootstrap are gone;
the SDK's own index.html with generic URL parameters is the only web
entry.
"""

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

    def test_moon_mod_pins_published_sdk_0_0_3(self):
        text = (REPO_ROOT / "moon.mod").read_text()
        self.assertIn(
            f'"{SDK_DEPENDENCY}",',
            text,
            "moon.mod must depend on the published SDK 0.0.3",
        )
        self.assertNotIn("colmugx/ai-passport@0.0.2", text)
        self.assertNotIn("colmugx/ai-passport@0.0.1", text)

    def test_no_moon_work(self):
        self.assertFalse(
            (REPO_ROOT / "moon.work").exists(),
            "moon.work would override the published dependency resolution",
        )

    def test_build_mbtx_generates_no_app_html(self):
        text = (REPO_ROOT / "tools" / "build.mbtx").read_text()
        for forbidden in ("ENTRY_PAGE", "write_entry_page", "createHost"):
            self.assertNotIn(
                forbidden,
                text,
                f"tools/build.mbtx must not own browser bootstrap ({forbidden})",
            )
        for line in text.splitlines():
            if "app.html" in line:
                self.assertTrue(
                    "@fs.remove" in line or "@fs.exists" in line,
                    "tools/build.mbtx may reference app.html only to remove "
                    f"a stale copy, found: {line.strip()}",
                )

    def test_built_web_bundle_has_no_app_html(self):
        bundle = REPO_ROOT / ".passport" / "web"
        if not (bundle / "app.wasm").is_file():
            self.skipTest("web bundle not built yet")
        self.assertFalse(
            (bundle / "app.html").exists(),
            ".passport/web/app.html must not exist; the SDK index.html is "
            "the only web entry",
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
