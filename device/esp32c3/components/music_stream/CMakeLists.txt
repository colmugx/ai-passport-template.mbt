set(MUSIC_PCM_FILE "${PROJECT_DIR}/generated/forest_walk.pcm")
if(NOT EXISTS "${MUSIC_PCM_FILE}")
    message(FATAL_ERROR "Device music PCM missing: ${MUSIC_PCM_FILE}; run ./device/build.sh")
endif()
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${MUSIC_PCM_FILE}")
idf_component_register(SRCS "music_stream.c"
    INCLUDE_DIRS "include"
    REQUIRES folotoy_bsp log freertos esp_timer)
# The PCM lives in flash via ELF embedding, never in a heap copy. RENAME_TO
# pins the linker symbols (_binary_forest_walk_pcm_start/_end) regardless of
# where the generated file sits.
target_add_binary_data(${COMPONENT_LIB} "${MUSIC_PCM_FILE}" BINARY RENAME_TO forest_walk_pcm)
