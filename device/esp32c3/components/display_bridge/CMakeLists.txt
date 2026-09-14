idf_component_register(
    SRCS "display_bridge.c"
    INCLUDE_DIRS "include"
    REQUIRES folotoy_display moonbit_runtime esp_lcd esp_timer heap freertos
)
