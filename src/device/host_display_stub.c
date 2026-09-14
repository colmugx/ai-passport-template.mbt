// Host-only native test linker stubs. Device firmware links the ESP-IDF
// display bridge and battery bridge instead.
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
