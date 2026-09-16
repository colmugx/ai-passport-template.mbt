// Host-only native test linker stubs. Device firmware links the ESP-IDF
// display bridge, battery bridge and music transport instead.
// Calling a display stub means the ESP-IDF display bridge was not linked as
// intended; the battery stub honestly reports "unavailable" because host
// builds have no CW2017 attached, which exercises the HUD's `--%` path.
#include <stdint.h>
#include <stdlib.h>

void ai_passport_display_begin(void) { abort(); }
void ai_passport_display_row(int32_t y, int32_t *row) {
    (void)y;
    (void)row;
    abort();
}
void ai_passport_display_end(void) { abort(); }

int32_t ai_passport_battery_soc(void) { return -1; }

// No audio hardware on hosts: the music position stays at the track start,
// so the walk clock holds pose 0.
int64_t ai_passport_music_position_us(void) { return 0; }

// Host builds have no esp_timer; the frozen zero keeps the host-side
// runtime tests deterministic (no time ever elapses unless a test drives
// the app clock itself).
int64_t ai_passport_now_us(void) { return 0; }

// Recording stand-in for the music transport's absolute output setter. The
// firmware's music_stream owns the real one; host tests read what the
// device adapter requested through the probes below. No control arithmetic
// lives here — the stub only records the facts it was handed.
static int32_t s_last_output_volume;
static int32_t s_last_output_muted;
static int32_t s_output_set_calls;

void ai_passport_music_set_output(int32_t volume, int32_t muted) {
    s_last_output_volume = volume;
    s_last_output_muted = muted;
    s_output_set_calls += 1;
}

int32_t ai_passport_test_last_output_volume(void) {
    return s_last_output_volume;
}

int32_t ai_passport_test_last_output_muted(void) {
    return s_last_output_muted;
}

int32_t ai_passport_test_output_set_calls(void) { return s_output_set_calls; }
