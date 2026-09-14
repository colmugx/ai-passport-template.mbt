// Host-only native test linker stub. Device firmware uses display_bridge.c.
// Calling it means the ESP-IDF display bridge was not linked as intended.
#include <stdint.h>
#include <stdlib.h>

void ai_passport_display_begin(void) { abort(); }
void ai_passport_display_row(int32_t y, int32_t *row) {
    (void)y;
    (void)row;
    abort();
}
void ai_passport_display_end(void) { abort(); }
