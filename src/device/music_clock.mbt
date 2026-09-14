///|
/// Musical position of device playback in microseconds within the current
/// loop iteration, read from the C music streaming task. Hardware knowledge
/// ends here; the scene only ever sees an eighth-note index.
extern "c" fn music_position_us() -> Int64 = "ai_passport_music_position_us"

///|
/// Converts a musical position in microseconds into the whole eighth-note
/// index at `dotted_quarter_bpm` (one dotted quarter is three eighths).
/// Int64 arithmetic keeps long silent-mode sessions exact.
fn musical_eighths_from_us(
  position_us : Int64,
  dotted_quarter_bpm : Int,
) -> Int {
  if dotted_quarter_bpm <= 0 {
    abort("dotted-quarter BPM must be positive")
  }
  if position_us <= 0L {
    return 0
  }
  (position_us * dotted_quarter_bpm.to_int64() * 3L / 60000000L).to_int()
}

///|
/// Current musical position for the fairy walk clock: one pose per eighth
/// note at the application tempo, whether or not audio is actually playing
/// (the C seam falls back to the boot clock in silent mode).
fn device_musical_eighths() -> Int {
  musical_eighths_from_us(
    music_position_us(),
    @forest_walk.MUSIC_DOTTED_QUARTER_BPM,
  )
}
