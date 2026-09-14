#include <stdint.h>
#include <stdlib.h>

#include "bsp_display.h"
#include "display_bridge.h"
#include "esp_err.h"
#include "esp_log.h"

extern void moonbit_init(void);
extern int32_t ai_passport_mbt_probe(void);
extern int32_t ai_passport_mbt_present_smoke(void);

void app_main(void) {
    moonbit_init();
    const int32_t probe = ai_passport_mbt_probe();
    ESP_LOGI("ai_passport", "MoonBit bridge probe: 0x%04lx", (unsigned long)probe);
    if (probe != 0xA17E) {
        ESP_LOGE("ai_passport", "MoonBit bridge probe mismatch");
        abort();
    }
    ESP_ERROR_CHECK(ai_passport_display_init());
    bsp_display_backlight(60);
    ESP_LOGI("ai_passport", "MoonBit Canvas 120x160 -> ST7789P3 240x320 present");
    (void)ai_passport_mbt_present_smoke();
}
