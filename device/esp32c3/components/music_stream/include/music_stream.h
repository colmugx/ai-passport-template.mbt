// Device background music: streams the flash-embedded Forest Walk PCM into
// the BSP audio codec. One FreeRTOS task uniquely owns every PCM write; the
// Forest Walk render loop and MoonBit code never touch audio transport.
#pragma once

#include "esp_err.h"

// Initializes the ES8311 codec over the BSP's shared I2C bus, opens the
// 16 kHz / 16-bit / mono playback format, sets the conservative startup
// volume, and starts the looping playback task. Idempotent: a second call
// returns ESP_OK without creating another task. On failure nothing is
// started and the error is returned; the caller keeps running without
// music.
esp_err_t ai_passport_music_start(void);

// Startup output volume in percent. No buttons yet; future contract is
// UP volume+, DOWN volume-, OK mute.
#define MUSIC_STARTUP_VOLUME_PERCENT 30

// Playback format of the generated device asset: signed PCM16
// little-endian, mono, 16000 Hz. tools/compile_audio.py guarantees it.
#define MUSIC_SAMPLE_RATE_HZ 16000
#define MUSIC_CHANNELS 1
#define MUSIC_BITS_PER_SAMPLE 16

// Musical position of device playback in microseconds within the current
// loop iteration, for the visual walk clock. Read-only and cheap: call it
// from the render loop. While the streaming task runs, the position is the
// loop-wrapped write offset, which leads the audible signal by at most the
// I2S DMA queue (about 100 ms — a fraction of one eighth note at 76 BPM).
// When music is not running, the boot clock is returned instead so the
// fairy keeps walking at tempo in silent mode.
int64_t ai_passport_music_position_us(void);
