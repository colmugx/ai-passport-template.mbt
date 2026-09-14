# Build orchestration for the official FoloToy BSP. No BSP source is copied
# into this repository: every file below is compiled straight from the
# pinned git submodule at external/folotoy-ai-passport.
#
# Upstream's own components/bsp/CMakeLists.txt also registers bsp_button.c
# and bsp_display_lvgl.c and REQUIRES esp_lvgl_port and the managed button
# component, which would drag all of LVGL into this firmware through
# whole-archive component linking. This product has no UI framework and
# spends its flash budget on the music PCM, so only the display, shared-I2C,
# battery and audio sources are selected here; the selection list is the
# single place to audit what enters the firmware.
set(FOLOTOY_BSP_SOURCE_DIR
    "${PROJECT_DIR}/../../external/folotoy-ai-passport/components/bsp")
if(NOT EXISTS "${FOLOTOY_BSP_SOURCE_DIR}/src/bsp_i2c.c")
    message(FATAL_ERROR
        "FoloToy BSP submodule is not checked out at "
        "${FOLOTOY_BSP_SOURCE_DIR}; run: git submodule update --init")
endif()
idf_component_register(
    SRCS "${FOLOTOY_BSP_SOURCE_DIR}/src/bsp_display.c"
         "${FOLOTOY_BSP_SOURCE_DIR}/src/bsp_i2c.c"
         "${FOLOTOY_BSP_SOURCE_DIR}/src/bsp_battery.c"
         "${FOLOTOY_BSP_SOURCE_DIR}/src/bsp_audio.c"
    INCLUDE_DIRS "${FOLOTOY_BSP_SOURCE_DIR}/include"
    REQUIRES esp_driver_spi esp_driver_ledc esp_lcd esp_driver_i2c esp_driver_i2s esp_codec_dev
)
