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
