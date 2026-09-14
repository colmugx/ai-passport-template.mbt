#include "battery_bridge.h"

#include <stdatomic.h>

#include "bsp_battery.h"
#include "esp_err.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

#define BATTERY_POLL_PERIOD_MS 1000
#define BATTERY_TASK_STACK 3072

static const char *TAG = "battery_bridge";

// Atomic so the render loop's reads never tear against the poll task.
static atomic_int_fast32_t s_soc = -1;

// One task initializes the gauge once and then polls it forever. A single
// failed read keeps the previous value: a transient I2C error must not
// flash "--%" over an otherwise healthy gauge; a stale value ages out after
// at most one polling period of permanent failure. Read failures are only
// logged once a valid reading existed, so a board without the gauge stays
// quiet after the one init error.
static void battery_task(void *arg) {
    (void)arg;
    bool ever_valid = false;
    esp_err_t err = bsp_battery_init();
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Battery gauge unavailable (%s); HUD will show --%%",
                 esp_err_to_name(err));
        // Keep polling: cw_read fails fast while no device is attached, and
        // the demo must not abort because battery is unavailable.
    } else {
        atomic_store(&s_soc, bsp_battery_soc());
        ever_valid = true;
        ESP_LOGI(TAG, "Battery gauge ready, SOC=%d mV=%d, polling every %d ms",
                 bsp_battery_soc(), bsp_battery_mv(), BATTERY_POLL_PERIOD_MS);
    }
    for (;;) {
        vTaskDelay(pdMS_TO_TICKS(BATTERY_POLL_PERIOD_MS));
        int soc = bsp_battery_soc();
        if (soc >= 0 && soc <= 100) {
            atomic_store(&s_soc, soc);
            ever_valid = true;
        } else if (ever_valid) {
            ESP_LOGW(TAG, "CW2017 SOC read failed (keep last reading)");
        }
    }
}

void ai_passport_battery_bridge_init(void) {
    // The gauge init can block for seconds waiting for the first SOC
    // computation, so it runs inside the task; the frame loop starts
    // immediately and shows "--%" until the first valid reading.
    if (xTaskCreate(battery_task, "battery", BATTERY_TASK_STACK,
                    NULL, tskIDLE_PRIORITY + 1, NULL) != pdPASS) {
        ESP_LOGE(TAG, "Battery task creation failed; HUD stays at --%%");
    }
}

int32_t ai_passport_battery_soc(void) {
    return (int32_t)atomic_load(&s_soc);
}
