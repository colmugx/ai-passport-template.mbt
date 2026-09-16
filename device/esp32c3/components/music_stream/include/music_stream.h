// Device background music: streams the flash-embedded Forest Walk PCM into
// the BSP audio codec. One FreeRTOS task uniquely owns every PCM write and
// every codec volume change; the Forest Walk render loop, the button
// callback and MoonBit code never touch audio transport.
#pragma once

#include <stdbool.h>
#include <stdint.h>

#include "esp_err.h"
#include "volume_control.h"

// Initializes the ES8311 codec over the BSP's shared I2C bus, opens the
// 16 kHz / 16-bit / mono playback format, sets the startup volume (80%,
// matching the official FoloToy audio demo) and starts the looping playback
// task. Idempotent: a second call returns ESP_OK without creating another
// task. On failure nothing is started and the error is returned; the caller
// keeps running without music and volume commands stay unavailable.
esp_err_t ai_passport_music_start(void);

// Playback format of the generated device asset: signed PCM16
// little-endian, mono, 16000 Hz. tools/compile_audio.py guarantees it.
#define MUSIC_SAMPLE_RATE_HZ 16000
#define MUSIC_CHANNELS 1
#define MUSIC_BITS_PER_SAMPLE 16

// Enqueues one volume/mute command for the music task. Safe from the button
// callback: it never blocks and allocates nothing. Returns true when the
// command was queued, false when audio is not running (nothing consumes the
// command) or the queue is full — a full queue drops the event rather than
// blocking the caller, and the drop is counted in
// ai_passport_music_dropped_commands().
bool music_stream_send_command(music_cmd_t command);

// Volume/mute commands dropped because the control queue was full. Purely
// diagnostic: a human pressing buttons faster than eight pending commands
// is not an error worth more than this counter.
uint32_t ai_passport_music_dropped_commands(void);

// Musical position of device playback in microseconds within the current
// loop iteration, for the visual walk clock. Read-only and cheap: call it
// from the render loop. While the streaming task runs, the position is the
// loop-wrapped write offset, which leads the audible signal by at most the
// I2S DMA queue (about 100 ms — a fraction of one eighth note at 76 BPM).
// When music is not running, the boot clock is returned instead so the
// fairy keeps walking at tempo in silent mode.
int64_t ai_passport_music_position_us(void);

// Monotonic device frame clock in microseconds (esp_timer passthrough).
// Feeds the portable application's fixed-step 30 Hz accumulator; unlike the
// music position it never wraps, so it is safe as a time base.
int64_t ai_passport_now_us(void);
