#include "button_bridge.h"

#include "bsp_button.h"
#include "esp_err.h"
#include "esp_log.h"
#include "music_stream.h"

static const char *TAG = "button_bridge";

// Runs in the button component's shared esp_timer task: only a bounded,
// non-blocking enqueue is allowed here — no codec writes, no audio writes,
// no blocking calls, no logging, no MoonBit calls. Only BSP_BTN_PRESS
// reacts, so one physical press produces exactly one action; CLICK, DOUBLE
// and LONG (also delivered for the same press) stay ignored. A full queue
// drops the event inside music_stream_send_command and never blocks.
static void on_button_event(bsp_btn_t button, bsp_btn_ev_t event, void *user) {
    (void)user;
    if (event != BSP_BTN_PRESS) {
        return;
    }
    switch (button) {
    case BSP_BTN_UP:
        (void)music_stream_send_command(MUSIC_CMD_VOLUME_UP);
        return;
    case BSP_BTN_DOWN:
        (void)music_stream_send_command(MUSIC_CMD_VOLUME_DOWN);
        return;
    case BSP_BTN_OK:
        (void)music_stream_send_command(MUSIC_CMD_TOGGLE_MUTE);
        return;
    }
}

esp_err_t ai_passport_button_bridge_init(void) {
    esp_err_t err = bsp_button_init(on_button_event, NULL);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Buttons unavailable (%s); volume/mute controls disabled",
                 esp_err_to_name(err));
        return err;
    }
    ESP_LOGI(TAG, "Buttons ready: UP volume+, DOWN volume-, OK mute");
    return ESP_OK;
}
