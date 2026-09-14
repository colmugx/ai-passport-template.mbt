"""Contract tests for the device button integration.

Guards the T4.1-B decisions that the build alone cannot prove on hosts:
the button driver comes from the pinned FoloToy submodule, the managed
button dependency is pinned to the version upstream uses, and LVGL /
esp_lvgl_port never enter this firmware's own component manifests.
"""

import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
COMPONENTS = REPO_ROOT / "device" / "esp32c3" / "components"
FOLOTOY_BSP = COMPONENTS / "folotoy_bsp"


class DeviceButtonContractTests(unittest.TestCase):
    def test_button_source_comes_from_pinned_submodule(self):
        cmake = (FOLOTOY_BSP / "CMakeLists.txt").read_text()
        self.assertIn("folotoy-ai-passport", cmake)
        self.assertIn("src/bsp_button.c", cmake)
        # No BSP source is copied into this repository.
        self.assertFalse(
            list((FOLOTOY_BSP).rglob("bsp_button.c")),
            "bsp_button.c must be compiled from the submodule, not copied",
        )

    def test_button_component_is_pinned_to_upstreams_version(self):
        manifest = (FOLOTOY_BSP / "idf_component.yml").read_text()
        self.assertIn('espressif/button: "4.2.0"', manifest)

    def test_lvgl_stays_out_of_the_firmware(self):
        # Comments may name what is deliberately excluded; only real
        # manifest/registration references count, so strip comments and scan
        # the build-graph files (idf_component.yml + CMakeLists.txt).
        offenders = []
        paths = sorted(COMPONENTS.rglob("CMakeLists.txt"))
        paths += sorted(COMPONENTS.rglob("*.yml"))
        for path in paths:
            relative = path.relative_to(COMPONENTS)
            active_lines = []
            for line in path.read_text(errors="replace").splitlines():
                if path.suffix == ".yml":
                    if not line.lstrip().startswith("#"):
                        active_lines.append(line)
                else:
                    active_lines.append(line.split("#", 1)[0])
            active = "\n".join(active_lines).lower()
            for banned in ("lvgl", "esp_lvgl_port"):
                if banned in active:
                    offenders.append(f"{relative}: {banned}")
        self.assertEqual(
            offenders, [],
            "LVGL must not be referenced by this firmware's components",
        )


if __name__ == "__main__":
    unittest.main()
