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
/// The device pose clock leads the reported playback position by this much.
/// Measured on hardware: with no lead the fairy's displayed steps landed
/// clearly after the audible beat; +150 ms overshot into a slight early
/// lead; 100 ms lands on the beat (a few ms late is chosen over early,
/// which the eye catches faster than the ear). Browser preview timing is
/// unaffected.
const FAIRY_POSE_LEAD_US : Int64 = 100_000L

///|
/// Position the fairy pose clock reads: the playback position advanced by
/// the measured hardware lead. A loop-wrapped position may cross the track
/// end here; the eighth index then continues past the loop's final eighth,
/// matching the existing loop-boundary phase behavior.
fn fairy_pose_position_us(position_us : Int64) -> Int64 {
  position_us + FAIRY_POSE_LEAD_US
}

///|
/// Current musical position for the fairy walk clock: one pose per eighth
/// note at the application tempo, whether or not audio is actually playing
/// (the C seam falls back to the boot clock in silent mode).
fn device_musical_eighths() -> Int {
  musical_eighths_from_us(
    fairy_pose_position_us(music_position_us()),
    @forest_walk.MUSIC_DOTTED_QUARTER_BPM,
  )
}
