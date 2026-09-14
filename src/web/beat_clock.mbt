///|
/// Duration of one dotted-quarter beat in seconds at `bpm`. In the 6/8 walk
/// meter a beat subdivides into three eighth notes.
pub fn beat_seconds(dotted_quarter_bpm : Int) -> Double {
  60.0 / dotted_quarter_bpm.to_double()
}

///|
/// Duration of one eighth note in seconds at `bpm` (a third of a
/// dotted-quarter beat). One fairy pose lasts exactly this long.
pub fn eighth_seconds(dotted_quarter_bpm : Int) -> Double {
  beat_seconds(dotted_quarter_bpm) / 3.0
}

///|
/// Browser-runtime-only visual music clock.
///
/// Before WebAudio is enabled, the walk cycle still needs a musical position.
/// This clock integrates elapsed monotonic browser time into whole eighth
/// notes at the music's tempo. The ambient scene keeps moving until WebAudio
/// supplies the audible playback position.
///
/// This remains pre-audio preview timing. After sound unlock, the runtime
/// derives the eighth index from the WebAudio playback head of the authored
/// music file.
pub struct BeatClock {
  priv dotted_quarter_bpm : Int
  priv mut elapsed : Double
}

///|
/// Creates a clock stopped at eighth zero for the given dotted-quarter tempo.
pub fn BeatClock::new(dotted_quarter_bpm~ : Int) -> BeatClock {
  { dotted_quarter_bpm, elapsed: 0.0, }
}

///|
/// Adds `dt` seconds of musical time. Negative deltas are ignored so a
/// reordered timestamp cannot run the clock backwards.
pub fn BeatClock::tick(self : BeatClock, dt : Double) -> Unit {
  if dt > 0.0 {
    self.elapsed += dt
  }
}

///|
/// Whole eighth-note index since the clock started. Used by the pre-audio
/// clock and by the audible playback head, so both count eighths
/// identically.
pub fn BeatClock::eighths(self : BeatClock) -> Int {
  music_eighths(self.elapsed, self.dotted_quarter_bpm)
}

///|
/// Maps a music playback position in seconds to the whole eighth-note index
/// at `bpm`.
pub fn music_eighths(
  position_seconds : Double,
  dotted_quarter_bpm : Int,
) -> Int {
  if dotted_quarter_bpm <= 0 {
    abort("dotted-quarter BPM must be positive")
  }
  if position_seconds <= 0.0 {
    return 0
  }
  (position_seconds / eighth_seconds(dotted_quarter_bpm)).floor().to_int()
}

///|
/// Position within one loop iteration of the authored track: elapsed time
/// wraps at the track duration, so looping never grows the eighth counter
/// and the walk cadence stays anchored to the audible music. A non-positive
/// duration (asset unknown or failed) pins the position at zero.
pub fn loop_position(
  elapsed_seconds : Double,
  duration_seconds : Double,
) -> Double {
  if duration_seconds <= 0.0 {
    return 0.0
  }
  let position = elapsed_seconds % duration_seconds
  if position < 0.0 {
    0.0
  } else {
    position
  }
}
