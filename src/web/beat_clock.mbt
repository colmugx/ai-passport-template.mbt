///|
/// Duration of one dotted-quarter beat in seconds at `bpm` (the starter song
/// uses 76). One walk-cycle weight shift happens per large 6/8 beat.
pub fn beat_seconds(dotted_quarter_bpm : Int) -> Double {
  60.0 / dotted_quarter_bpm.to_double()
}

///|
/// Browser-runtime-only visual beat clock.
///
/// WebAudio is intentionally not part of the T1 preview, but the walk cycle
/// still needs a beat value. This clock integrates elapsed monotonic browser
/// time into whole dotted-quarter beats at the song's tempo. The frame loop
/// only feeds it while the scene is unpaused, so pausing freezes the beat and
/// resuming continues from the same elapsed musical time.
///
/// This is temporary T1 glue that lives outside `forest_walk`: T2 WebAudio
/// replaces `beat()` reads with the authoritative `Player::beat()` from the
/// audio transport.
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
/// Adds `dt` seconds of musical time only while the scene is `active`
/// (unpaused). Pausing freezes the clock and resuming continues from the same
/// elapsed musical time.
pub fn BeatClock::tick_active(
  self : BeatClock,
  dt : Double,
  active~ : Bool,
) -> Unit {
  if active {
    self.tick(dt)
  }
}

///|
/// Current whole beat index since the clock started, floored at the song's
/// dotted-quarter tempo.
pub fn BeatClock::beat(self : BeatClock) -> Int {
  (self.elapsed / beat_seconds(self.dotted_quarter_bpm)).floor().to_int()
}
