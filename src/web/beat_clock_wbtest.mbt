///|
test "beat_seconds is 60/bpm for the starter song tempo" {
  inspect(beat_seconds(76), content="0.7894736842105263")
}

///|
test "BeatClock floors elapsed time into whole beats" {
  let clock = BeatClock::new(dotted_quarter_bpm=76)
  inspect(clock.beat(), content="0")
  // Half a beat in: still beat 0.
  clock.tick(beat_seconds(76) / 2)
  inspect(clock.beat(), content="0")
  // A full beat later: beat 1.
  clock.tick(beat_seconds(76) / 2)
  inspect(clock.beat(), content="1")
  // Negative deltas are ignored.
  clock.tick(-beat_seconds(76))
  inspect(clock.beat(), content="1")
  // Four beats in: the clock reports the elapsed musical beat directly.
  clock.tick(beat_seconds(76) * 3)
  inspect(clock.beat(), content="4")
}
