idf_component_register(
    SRCS "src/bsp_display.c"
    INCLUDE_DIRS "include"
    REQUIRES esp_driver_spi esp_driver_ledc esp_lcd
)
