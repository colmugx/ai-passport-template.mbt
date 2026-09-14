///|
test "beat_seconds and eighth_seconds derive from the tempo" {
  inspect(beat_seconds(76), content="0.7894736842105263")
  // One dotted quarter is exactly three eighth notes in the 6/8 walk meter.
  inspect(
    eighth_seconds(76),
    content=(
      #|0.2631578947368421
    ),
  )
}

///|
test "BeatClock floors elapsed time into whole eighths" {
  let clock = BeatClock::new(dotted_quarter_bpm=76)
  inspect(clock.eighths(), content="0")
  // Half an eighth in: still eighth 0.
  clock.tick(eighth_seconds(76) / 2)
  inspect(clock.eighths(), content="0")
  // A full eighth later: eighth 1.
  clock.tick(eighth_seconds(76) / 2)
  inspect(clock.eighths(), content="1")
  // Negative deltas are ignored.
  clock.tick(-eighth_seconds(76))
  inspect(clock.eighths(), content="1")
  // One dotted-quarter beat (three eighths) more: eighth 4.
  clock.tick(beat_seconds(76))
  inspect(clock.eighths(), content="4")
}
