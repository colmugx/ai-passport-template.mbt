"""Host unit test for the device volume/mute state machine.

Compiles the firmware's pure volume_control.h with the host C compiler and
checks every required button transition. The header is the same code the
music task runs on the ESP32-C3; no ESP-IDF stubs are needed.
"""

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
HEADER_DIR = (
    REPO_ROOT / "device" / "esp32c3" / "components" / "music_stream" / "include"
)

# (start volume, start muted, command, expected volume, expected muted,
#  expected codec output)
CASES = [
    # UP steps by 10 and clamps at 100.
    (80, 0, "MUSIC_CMD_VOLUME_UP", 90, 0, 90),
    (90, 0, "MUSIC_CMD_VOLUME_UP", 100, 0, 100),
    (100, 0, "MUSIC_CMD_VOLUME_UP", 100, 0, 100),
    # DOWN steps by 10 and clamps at 0.
    (80, 0, "MUSIC_CMD_VOLUME_DOWN", 70, 0, 70),
    (10, 0, "MUSIC_CMD_VOLUME_DOWN", 0, 0, 0),
    (0, 0, "MUSIC_CMD_VOLUME_DOWN", 0, 0, 0),
    # OK toggles mute; codec goes to 0 and back to the remembered volume.
    (80, 0, "MUSIC_CMD_TOGGLE_MUTE", 80, 1, 0),
    (80, 1, "MUSIC_CMD_TOGGLE_MUTE", 80, 0, 80),
    # While muted, UP/DOWN still move the remembered volume but the codec
    # stays at 0 — nothing but OK clears the mute.
    (80, 1, "MUSIC_CMD_VOLUME_UP", 90, 1, 0),
    (80, 1, "MUSIC_CMD_VOLUME_DOWN", 70, 1, 0),
]

TEST_PROGRAM = r"""
#include <stdio.h>
#include "volume_control.h"

struct case_t {
    int start_volume;
    int start_muted;
    music_cmd_t command;
    int want_volume;
    int want_muted;
    int want_codec;
};

int main(int argc, char **argv) {
    const struct case_t cases[] = {
%s
    };
    const size_t count = sizeof(cases) / sizeof(cases[0]);
    for (size_t i = 0; i < count; i++) {
        const struct case_t *c = &cases[i];
        music_volume_state_t state = { c->start_volume, c->start_muted };
        state = music_volume_apply(state, c->command);
        const int codec = music_volume_codec(&state);
        if (state.volume != c->want_volume || state.muted != c->want_muted
                || codec != c->want_codec) {
            printf("case %%zu: %%d/%%d + %%d -> %%d/%%d codec=%%d"
                   " (want %%d/%%d codec=%%d)\\n",
                   i, c->start_volume, c->start_muted, (int)c->command,
                   state.volume, state.muted, codec,
                   c->want_volume, c->want_muted, c->want_codec);
            return 1;
        }
    }
    if (MUSIC_VOLUME_INITIAL != 80 || MUSIC_VOLUME_STEP != 10) {
        puts("startup volume/step drifted from the agreed contract");
        return 1;
    }
    const music_volume_state_t boot = { MUSIC_VOLUME_INITIAL, false };
    if (music_volume_codec(&boot) != 80) {
        puts("startup codec volume is not 80");
        return 1;
    }
    (void)argc; (void)argv;
    puts("ok");
    return 0;
}
"""


class VolumeControlTests(unittest.TestCase):
    def setUp(self):
        if shutil.which("cc") is None:
            self.skipTest("host C compiler is not installed")

    def test_button_transitions(self):
        rows = []
        for volume, muted, command, want_volume, want_muted, want_codec in CASES:
            rows.append(
                f"        {{{volume}, {muted}, {command}, "
                f"{want_volume}, {want_muted}, {want_codec}}},"
            )
        source = TEST_PROGRAM % "\n".join(rows)
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "test.c").write_text(source)
            binary = root / "test"
            compile_result = subprocess.run(
                ["cc", "-std=c11", "-Wall", "-Werror",
                 "-I", str(HEADER_DIR), str(root / "test.c"), "-o", str(binary)],
                capture_output=True,
                text=True,
            )
            self.assertEqual(
                compile_result.returncode, 0, compile_result.stderr or "compile failed"
            )
            run_result = subprocess.run(
                [str(binary)], capture_output=True, text=True
            )
            self.assertEqual(run_result.returncode, 0, run_result.stdout)
            self.assertIn("ok", run_result.stdout)


if __name__ == "__main__":
    unittest.main()
