///|
/// Duration of one dotted-quarter beat in seconds at `bpm` (the starter song
/// uses 76). One walk-cycle weight shift happens per large 6/8 beat.
pub fn beat_seconds(dotted_quarter_bpm : Int) -> Double {
  60.0 / dotted_quarter_bpm.to_double()
}

///|
/// Browser-runtime-only visual beat clock.
///
/// Before WebAudio is enabled, the walk cycle still needs a beat value. This
/// clock integrates elapsed monotonic browser
/// time into whole dotted-quarter beats at the song's tempo. The ambient
/// scene keeps moving until WebAudio supplies an audible playback beat.
///
/// This remains pre-audio preview timing. After sound unlock, the runtime
/// derives the visible beat from WebAudio's audible playback head; the SDK
/// Player is ahead of playback because it pre-renders queued PCM.
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
/// Current whole beat index since the clock started, floored at the song's
/// dotted-quarter tempo.
pub fn BeatClock::beat(self : BeatClock) -> Int {
  (self.elapsed / beat_seconds(self.dotted_quarter_bpm)).floor().to_int()
}
