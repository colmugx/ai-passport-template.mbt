///|
/// Musical position of device playback in microseconds within the current
/// loop iteration, read from the C music streaming task. Hardware knowledge
/// ends here; the portable application derives the eighth-note index.
extern "c" fn music_position_us() -> Int64 = "ai_passport_music_position_us"

///|
/// Transport availability fact from the C music stream (1 = the streaming
/// task started, 0 = unavailable). The fact decides playback availability —
/// the position value never infers it.
extern "c" fn music_available() -> Int = "ai_passport_music_available"

///|
/// Live device playback position for the portable App: `Some(position)` —
/// INCLUDING exactly 0 at the track start and at the PCM loop boundary —
/// when the transport is running, `None` when music is unavailable. Handed
/// straight to `App::advance` as its playback Option; the App owns the
/// loop wrap, presentation lead and fallback semantics.
fn device_playback_position_us() -> Int64? {
  if music_available() == 1 {
    Some(music_position_us())
  } else {
    None
  }
}

///|
/// Monotonic device frame clock in microseconds (esp_timer via the C music
/// stream component). Drives the portable application's fixed-step 30 Hz
/// accumulator; unlike the music position it never wraps.
extern "c" fn device_now_us() -> Int64 = "ai_passport_now_us"
