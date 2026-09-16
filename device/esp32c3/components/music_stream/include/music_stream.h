// Device background music transport: streams the flash-embedded Forest Walk
// PCM into the BSP audio codec. One FreeRTOS task uniquely owns every PCM
// write and every codec volume change; the Forest Walk render loop, the
// button callback and MoonBit code never touch audio transport.
//
// The transport holds no control semantics. It receives the ABSOLUTE desired
// output state (volume 0..100, muted) that the portable App decided, stored
// latest-wins in a packed atomic — there is no command queue and no
// UP/DOWN/OK knowledge here.
#pragma once

#include <stdbool.h>
#include <stdint.h>

#include "esp_err.h"

// Initializes the ES8311 codec over the BSP's shared I2C bus and opens the
// 16 kHz / 16-bit / mono playback format. The desired output state comes
// from the caller as App-owned facts (`initial_volume` 0..100 plus
// `initial_muted`): the streaming task writes that state to the codec once,
// from the audio-owning context, before the first PCM sample. Idempotent: a
// second call returns ESP_OK without creating another task. On failure
// nothing is started and the error is returned; the caller keeps running
// without music and set_output simply never reaches a codec.
esp_err_t ai_passport_music_start(int initial_volume, bool initial_muted);

// Playback format of the generated device asset: signed PCM16
// little-endian, mono, 16000 Hz. tools/compile_audio.py guarantees it.
#define MUSIC_SAMPLE_RATE_HZ 16000
#define MUSIC_CHANNELS 1
#define MUSIC_BITS_PER_SAMPLE 16

// Publishes the absolute desired output state decided by the portable App:
// `volume` is the remembered setting (0..100 per the App's Controls) and
// `muted` mutes the codec output while the remembered setting is preserved.
// Latest state wins: one packed atomic store, so volume and mute always
// travel as one coherent snapshot. Safe from the frame task and from any
// other context: it never blocks, never allocates and is meaningful even
// when music failed to start (the state is stored; nothing consumes it).
// Redundant identical states cause no codec write: the music task applies
// a change exactly once.
void ai_passport_music_set_output(int volume, bool muted);

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
