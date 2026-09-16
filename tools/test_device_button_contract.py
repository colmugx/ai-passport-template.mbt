"""Contract tests for the device button integration.

Guards the T4.1-B decisions that the build alone cannot prove on hosts:
the button driver comes from the pinned FoloToy submodule, the managed
button dependency is pinned to the version upstream uses, and LVGL /
esp_lvgl_port never enter this firmware's own component manifests.

Also guards the R2B control-ownership contract: input delivery carries
raw device-neutral press events only, the portable @app.App is the single
UP/DOWN/OK semantic owner, the music transport receives absolute output
state instead of semantic commands, and the duplicate C volume/mute state
machine stays removed.
"""

import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
COMPONENTS = REPO_ROOT / "device" / "esp32c3" / "components"
FOLOTOY_BSP = COMPONENTS / "folotoy_bsp"
DEVICE = REPO_ROOT / "device" / "esp32c3"
BUTTON_BRIDGE = COMPONENTS / "button_bridge"
MUSIC_STREAM = COMPONENTS / "music_stream"
MAIN = DEVICE / "main" / "app_main.c"
DEVICE_MOONBIT = REPO_ROOT / "src" / "device"


def c_code(path: Path) -> str:
    """File contents with C comments stripped, for structural scans."""
    lines = []
    for line in path.read_text(errors="replace").splitlines():
        lines.append(line.split("//", 1)[0])
    return "\n".join(lines)


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


class ControlOwnershipContractTests(unittest.TestCase):
    """R2B: exactly one owner of the UP/DOWN/OK semantics — src/app."""

    def test_button_bridge_has_no_music_stream_dependency(self):
        cmake = (BUTTON_BRIDGE / "CMakeLists.txt").read_text()
        self.assertNotIn(
            "music_stream", cmake,
            "input delivery must not depend on the music transport",
        )
        for source in (BUTTON_BRIDGE / "button_bridge.c",
                       BUTTON_BRIDGE / "include" / "button_bridge.h"):
            self.assertNotIn(
                "music_stream", c_code(source),
                f"{source.name} must not reference the music transport",
            )
            self.assertNotIn(
                "MUSIC_", c_code(source),
                f"{source.name} must carry no music control semantics",
            )

    def test_button_callback_stays_bounded_and_semantic_free(self):
        code = c_code(BUTTON_BRIDGE / "button_bridge.c")
        callback = code[code.index("on_button_event"):]
        callback = callback[:callback.index("esp_err_t ai_passport_button_bridge_init")]
        self.assertIn("BSP_BTN_PRESS", callback)
        self.assertIn("xQueueSend", callback)
        self.assertIn(
            "xQueueSend(s_events,&code,0)", callback.replace(" ", ""),
            "the callback enqueue must use zero wait",
        )
        for banned in ("bsp_audio", "ESP_LOG", "malloc", "vTaskDelay",
                       "ai_passport_mbt", "volume", "mute"):
            self.assertNotIn(
                banned, callback,
                f"the BSP timer callback must stay free of '{banned}'",
            )

    def test_obsolete_c_volume_state_machine_is_gone(self):
        self.assertFalse(
            (MUSIC_STREAM / "include" / "volume_control.h").exists(),
            "the duplicate C volume state machine header must stay deleted",
        )
        self.assertFalse(
            (REPO_ROOT / "tools" / "test_volume_control.py").exists(),
            "the host test of the removed state machine must stay deleted",
        )
        banned_symbols = (
            "music_cmd_t", "music_volume_state_t", "music_volume_apply",
            "music_volume_codec", "MUSIC_CMD_", "MUSIC_VOLUME_",
            "music_stream_send_command", "ai_passport_music_dropped_commands",
        )
        offenders = []
        for path in sorted(DEVICE.rglob("*")):
            if path.suffix not in (".c", ".h", ".txt", ".md"):
                continue
            text = path.read_text(errors="replace")
            for symbol in banned_symbols:
                if symbol in text:
                    offenders.append(f"{path.relative_to(DEVICE)}: {symbol}")
        self.assertEqual(
            offenders, [],
            "semantic music commands must stay removed from the device tree",
        )

    def test_music_transport_takes_absolute_output_only(self):
        header = c_code(MUSIC_STREAM / "include" / "music_stream.h")
        self.assertIn("ai_passport_music_set_output(int volume, bool muted)",
                      header)
        self.assertIn(
            "ai_passport_music_start(int initial_volume, bool initial_muted)",
            header,
        )
        code = c_code(MUSIC_STREAM / "music_stream.c")
        self.assertIn("atomic_", code,
                      "desired output must travel through one atomic")
        self.assertNotIn(
            "xQueueCreate", code,
            "absolute output state must not use a command queue",
        )
        self.assertNotIn(
            "= 80", code,
            "the transport must not hard-code the App's startup volume",
        )

    def test_frame_task_delivers_at_most_one_press_per_frame(self):
        code = c_code(MAIN)
        self.assertEqual(
            code.count("ai_passport_button_bridge_poll"), 1,
            "the frame loop must poll the button queue exactly once per frame",
        )
        self.assertIn("ai_passport_mbt_input_press", code)
        # No semantic volume/mute knowledge in app_main.
        for banned in ("MUSIC_CMD", "VOLUME_", "volume +", "mute toggle"):
            self.assertNotIn(banned, code)

    def test_device_adapter_uses_the_shared_app_controls(self):
        input_bridge = (DEVICE_MOONBIT / "input_bridge.mbt").read_text()
        self.assertIn("ai_passport_mbt_input_press", input_bridge)
        self.assertIn("app.input(button, true)", input_bridge)
        self.assertIn("app.input(button, false)", input_bridge)
        audio_bridge = (DEVICE_MOONBIT / "audio_output_bridge.mbt").read_text()
        self.assertIn("app.volume()", audio_bridge)
        self.assertIn("app.muted()", audio_bridge)
        # The App stays the only place the constants live.
        for path in sorted(DEVICE_MOONBIT.glob("*.mbt")):
            text = path.read_text()
            for banned in ("VOLUME_STEP", "VOLUME_STARTUP", "= 80", "+ 10",
                           "- 10"):
                self.assertNotIn(
                    banned, text,
                    f"{path.name} duplicates @app control arithmetic",
                )

    def test_telemetry_reports_button_drops(self):
        code = c_code(MAIN)
        self.assertIn("dropped_button_events=", code)
        self.assertIn("ai_passport_button_dropped_events", code)
        self.assertNotIn("dropped_cmds", code)


if __name__ == "__main__":
    unittest.main()

