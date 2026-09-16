///|
/// Musical position of device playback in microseconds within the current
/// loop iteration, read from the C music streaming task. Hardware knowledge
/// ends here; the portable application derives the eighth-note index.
extern "c" fn music_position_us() -> Int64 = "ai_passport_music_position_us"

///|
/// Monotonic device frame clock in microseconds (esp_timer via the C music
/// stream component). Drives the portable application's fixed-step 30 Hz
/// accumulator; unlike the music position it never wraps.
extern "c" fn device_now_us() -> Int64 = "ai_passport_now_us"
