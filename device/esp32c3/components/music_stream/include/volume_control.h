// Pure volume/mute arithmetic for the device music stream. Compiled into
// the firmware by music_stream.c and compiled on the host by
// tools/test_volume_control.py, so it must stay free of ESP-IDF and
// FreeRTOS includes.
#pragma once

#include <stdbool.h>

#define MUSIC_VOLUME_MIN 0
#define MUSIC_VOLUME_MAX 100
#define MUSIC_VOLUME_STEP 10
// Startup volume: the official FoloToy audio demo also plays at 80%.
#define MUSIC_VOLUME_INITIAL 80

// Control commands the music task accepts. The button bridge only enqueues
// these; only the music task executes them against the codec.
typedef enum {
    MUSIC_CMD_VOLUME_UP = 0,
    MUSIC_CMD_VOLUME_DOWN,
    MUSIC_CMD_TOGGLE_MUTE,
} music_cmd_t;

// Volume state, owned by the music task. `volume` is the remembered setting
// (0..100); while muted, the codec is driven at 0 and the remembered value
// is preserved so unmuting restores it.
typedef struct {
    int volume;
    bool muted;
} music_volume_state_t;

// Applies one control command and returns the next state. UP/DOWN clamp to
// 0..100 and never clear the mute flag; TOGGLE_MUTE never touches the
// remembered volume — OK is the only mute/unmute control.
static inline music_volume_state_t music_volume_apply(
    music_volume_state_t state, music_cmd_t command) {
    switch (command) {
    case MUSIC_CMD_VOLUME_UP:
        if (state.volume > MUSIC_VOLUME_MAX - MUSIC_VOLUME_STEP) {
            state.volume = MUSIC_VOLUME_MAX;
        } else {
            state.volume += MUSIC_VOLUME_STEP;
        }
        return state;
    case MUSIC_CMD_VOLUME_DOWN:
        if (state.volume < MUSIC_VOLUME_MIN + MUSIC_VOLUME_STEP) {
            state.volume = MUSIC_VOLUME_MIN;
        } else {
            state.volume -= MUSIC_VOLUME_STEP;
        }
        return state;
    case MUSIC_CMD_TOGGLE_MUTE:
        state.muted = !state.muted;
        return state;
    }
    return state;
}

// The volume actually written to the codec: zero while muted, otherwise the
// remembered setting.
static inline int music_volume_codec(const music_volume_state_t *state) {
    return state->muted ? 0 : state->volume;
}
