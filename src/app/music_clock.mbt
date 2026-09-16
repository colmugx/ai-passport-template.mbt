///|
/// Converts a musical position in microseconds into the whole eighth-note
/// index at `dotted_quarter_bpm` (one dotted quarter is three eighths).
/// Int64 arithmetic keeps long sessions exact; one fairy pose lasts exactly
/// one eighth note.
pub fn musical_eighths(position_us : Int64, dotted_quarter_bpm : Int) -> Int {
  if dotted_quarter_bpm <= 0 {
    abort("dotted-quarter BPM must be positive")
  }
  if position_us <= 0L {
    return 0
  }
  (position_us * dotted_quarter_bpm.to_int64() * 3L / 60000000L).to_int()
}

///|
/// Position within one loop iteration of the canonical PCM artifact: the
/// playback position wraps at the canonical duration, so looping never grows
/// the eighth counter and the walk cadence stays anchored to the audible
/// music on every host. A non-positive duration (asset unknown) pins the
/// position at zero.
pub fn loop_position_us(position_us : Int64, duration_us : Int64) -> Int64 {
  if duration_us <= 0L {
    return 0L
  }
  let position = position_us % duration_us
  if position < 0L {
    0L
  } else {
    position
  }
}

///|
/// Pre-audio visual beat clock. While audible playback is unavailable
/// (browser audio locked or failed, no audio backend), the walk cycle still
/// needs a musical position: this clock integrates elapsed monotonic frame
/// time into whole eighth notes at the application tempo, so the fairy keeps
/// stepping at tempo. The moment a real playback position appears, the app
/// reads that instead; this clock never runs while it does.
pub struct BeatClock {
  priv mut elapsed_us : Int64
}

///|
/// Creates a clock stopped at eighth zero.
pub fn BeatClock::new() -> BeatClock {
  { elapsed_us: 0L, }
}

///|
/// Adds `delta_us` of musical time. Negative deltas are ignored so a
/// reordered timestamp cannot run the clock backwards.
pub fn BeatClock::tick(self : BeatClock, delta_us : Int64) -> Unit {
  if delta_us > 0L {
    self.elapsed_us += delta_us
  }
}

///|
/// Whole eighth-note index since the clock started, at
/// `dotted_quarter_bpm`.
pub fn BeatClock::eighths(self : BeatClock, dotted_quarter_bpm : Int) -> Int {
  musical_eighths(self.elapsed_us, dotted_quarter_bpm)
}
