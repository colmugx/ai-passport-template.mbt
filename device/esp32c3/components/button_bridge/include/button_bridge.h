// Button bridge: wires the official FoloToy ADC button driver (UP / DOWN /
// OK on one shared GPIO0/ADC1_CH0 line) to music stream control commands.
// The bridge holds no Forest Walk state and routes nothing through MoonBit.
#pragma once

#include "esp_err.h"

// Registers the single button callback with the BSP. Never blocks; a
// failure only disables the volume/mute controls — the caller keeps the
// demo and music running.
esp_err_t ai_passport_button_bridge_init(void);
