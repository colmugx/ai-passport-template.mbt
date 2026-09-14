#include "music_stream.h"

#include <stdatomic.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "bsp_audio.h"
#include "esp_err.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

// The generated asset is embedded as raw PCM16 little-endian mono 16 kHz.
extern const uint8_t forest_walk_pcm_start[] asm("_binary_forest_walk_pcm_start");
extern const uint8_t forest_walk_pcm_end[] asm("_binary_forest_walk_pcm_end");

#define PCM_CHUNK_SAMPLES 240        // 15 ms of audio; a few hundred samples
#define PCM_CHUNK_BYTES (PCM_CHUNK_SAMPLES * (MUSIC_BITS_PER_SAMPLE / 8))
#define MUSIC_TASK_STACK 3072
#define MUSIC_TASK_PRIORITY (tskIDLE_PRIORITY + 2)
// Retry cadence for a failed write: log at most once per second, never spin.
#define MUSIC_RETRY_DELAY_MS 20
#define MUSIC_ERROR_LOG_PERIOD_MS 1000

static const char *TAG = "music_stream";

static bool s_started;
// Loop-wrapped write offset in samples (bytes / 2), published for the
// visual walk clock. Atomic: the render loop reads it without a lock.
static atomic_int s_loop_sample;

// Streams bounded chunks straight from flash-mapped memory into the codec.
// bsp_audio_write blocks until the DMA queue accepts the chunk, which paces
// the loop at real time. At end of stream the offset restarts at zero: the
// loop boundary does not allocate and cannot accumulate latency.
static void music_task(void *arg) {
    (void)arg;
    const size_t total = (size_t)(forest_walk_pcm_end - forest_walk_pcm_start);
    size_t offset = 0;
    TickType_t last_error_log = 0;
    for (;;) {
        size_t remaining = total - offset;
        size_t bytes = remaining < PCM_CHUNK_BYTES ? remaining : PCM_CHUNK_BYTES;
        esp_err_t err = bsp_audio_write(forest_walk_pcm_start + offset, bytes);
        if (err == ESP_OK) {
            offset += bytes;
            if (offset >= total) {
                offset = 0; // loop the authored track from its beginning
            }
            atomic_store(&s_loop_sample, (int)(offset / 2));
            continue;
        }
        // Keep the offset: a failed write consumed no samples, so the track
        // resumes exactly where it stopped instead of skipping audio.
        TickType_t now = xTaskGetTickCount();
        if ((now - last_error_log) >= pdMS_TO_TICKS(MUSIC_ERROR_LOG_PERIOD_MS)) {
            last_error_log = now;
            ESP_LOGE(TAG, "PCM write failed (%s); retrying",
                     esp_err_to_name(err));
        }
        vTaskDelay(pdMS_TO_TICKS(MUSIC_RETRY_DELAY_MS));
    }
}

esp_err_t ai_passport_music_start(void) {
    if (s_started) {
        return ESP_OK;
    }
    esp_err_t err = bsp_audio_init();
    if (err != ESP_OK) {
        return err;
    }
    err = bsp_audio_set_format(MUSIC_SAMPLE_RATE_HZ, MUSIC_BITS_PER_SAMPLE,
                               MUSIC_CHANNELS);
    if (err != ESP_OK) {
        return err;
    }
    bsp_audio_set_volume(MUSIC_STARTUP_VOLUME_PERCENT);
    if (xTaskCreate(music_task, "music_stream", MUSIC_TASK_STACK, NULL,
                    MUSIC_TASK_PRIORITY, NULL) != pdPASS) {
        return ESP_ERR_NO_MEM;
    }
    s_started = true;
    const size_t total = (size_t)(forest_walk_pcm_end - forest_walk_pcm_start);
    ESP_LOGI(TAG,
             "Music streaming %u bytes of PCM16/%dHz/mono in %u-sample chunks at %d%% volume",
             (unsigned)total, MUSIC_SAMPLE_RATE_HZ, PCM_CHUNK_SAMPLES,
             MUSIC_STARTUP_VOLUME_PERCENT);
    return ESP_OK;
}

int64_t ai_passport_music_position_us(void) {
    if (!s_started) {
        // Silent mode (init failed or not yet started): keep the walk clock
        // moving on the boot timeline so the fairy still steps at tempo.
        return esp_timer_get_time();
    }
    const int sample = atomic_load(&s_loop_sample);
    return (int64_t)sample * 1000000LL / MUSIC_SAMPLE_RATE_HZ;
}
