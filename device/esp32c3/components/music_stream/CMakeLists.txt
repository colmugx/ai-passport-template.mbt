# The device embeds the ONE canonical normalized PCM artifact byte-for-byte;
# the web bundle serves the same file. There is no device-side conversion:
# tools/compile_audio.py writes .passport/assets/forest_walk.pcm once per
# build workflow and both consumers resolve to it (tools/verify_pcm_identity.py).
get_filename_component(REPO_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../.." ABSOLUTE)
set(MUSIC_PCM_FILE "${REPO_ROOT}/.passport/assets/forest_walk.pcm")
if(NOT EXISTS "${MUSIC_PCM_FILE}")
    message(FATAL_ERROR "Device music PCM missing: ${MUSIC_PCM_FILE}; run moon run tools/passport.mbtx assets")
endif()
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${MUSIC_PCM_FILE}")
idf_component_register(SRCS "music_stream.c"
    INCLUDE_DIRS "include"
    REQUIRES folotoy_bsp log freertos esp_timer)
# The PCM lives in flash via ELF embedding, never in a heap copy. RENAME_TO
# pins the linker symbols (_binary_forest_walk_pcm_start/_end) regardless of
# where the generated file sits.
target_add_binary_data(${COMPONENT_LIB} "${MUSIC_PCM_FILE}" BINARY RENAME_TO forest_walk_pcm)
