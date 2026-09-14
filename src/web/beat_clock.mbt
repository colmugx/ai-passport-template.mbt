///|
/// Duration of one dotted-quarter beat in seconds at `bpm`. The Forest Walk
/// music tempo is an application constant; runtimes that play audio derive
/// the audible beat from their playback head against it.
pub fn beat_seconds(dotted_quarter_bpm : Int) -> Double {
  60.0 / dotted_quarter_bpm.to_double()
}

///|
/// Browser-runtime-only visual beat clock.
///
/// Before WebAudio is enabled, the walk cycle still needs a beat value. This
/// clock integrates elapsed monotonic browser
/// time into whole dotted-quarter beats at the music's tempo. The ambient
/// scene keeps moving until WebAudio supplies an audible playback beat.
///
/// This remains pre-audio preview timing. After sound unlock, the runtime
/// derives the visible beat from the WebAudio playback head of the authored
/// music file.
pub struct BeatClock {
  priv dotted_quarter_bpm : Int
  priv mut elapsed : Double
}

///|
/// Creates a clock stopped at beat 0 for the given dotted-quarter tempo.
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
/// Current whole beat index since the clock started, floored at the music's
/// dotted-quarter tempo.
pub fn BeatClock::beat(self : BeatClock) -> Int {
  music_beat(self.elapsed, self.dotted_quarter_bpm)
}

///|
/// Maps a music playback position in seconds to the whole dotted-quarter
/// beat at `bpm`. Used both by the pre-audio clock and by the audible
/// playback head, so both count beats identically.
pub fn music_beat(position_seconds : Double, dotted_quarter_bpm : Int) -> Int {
  if dotted_quarter_bpm <= 0 {
    abort("dotted-quarter BPM must be positive")
  }
  if position_seconds <= 0.0 {
    return 0
  }
  (position_seconds / beat_seconds(dotted_quarter_bpm)).floor().to_int()
}

///|
/// Position within one loop iteration of the authored track: elapsed time
/// wraps at the track duration, so looping never grows the beat counter and
/// the walk cadence stays anchored to the audible music. A non-positive
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
