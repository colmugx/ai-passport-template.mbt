///|
test "music eighths use exact 76 BPM boundaries" {
  // One eighth at 76 dotted-quarter BPM is 60/228 seconds; one beat is
  // three eighths, one 6/8 bar is six.
  assert_eq(music_eighths(0.0, 76), 0)
  assert_eq(music_eighths(0.263156, 76), 0)
  assert_eq(music_eighths(0.263158, 76), 1)
  assert_eq(music_eighths(0.789472, 76), 2)
  assert_eq(music_eighths(0.789474, 76), 3)
  assert_eq(music_eighths(1.578946, 76), 5)
  assert_eq(music_eighths(1.578948, 76), 6)
  assert_eq(music_eighths(60.0, 76), 228)
}

///|
test "music eighths use the supplied tempo and clamp bad ranges" {
  // At 60 BPM one eighth is a third of a second.
  assert_eq(music_eighths(0.99999, 60), 2)
  assert_eq(music_eighths(1.0, 60), 3)
  assert_eq(music_eighths(2.0, 120), 12)
  assert_eq(music_eighths(-5.0, 120), 0)
}

///|
test "loop position wraps at the track duration" {
  assert_eq(loop_position(0.0, 76.4), 0.0)
  assert_eq(loop_position(10.0, 76.4), 10.0)
  assert_eq(loop_position(76.4, 76.4), 0.0)
  assert_true((loop_position(80.0, 76.4) - 3.6).abs() < 0.000000001)
  assert_true((loop_position(160.0, 76.4) - 7.2).abs() < 0.000000001)
  // Unknown or failed asset pins the audible position at zero.
  assert_eq(loop_position(10.0, 0.0), 0.0)
  assert_eq(loop_position(-1.0, 76.4), 0.0)
}

///|
test "pre-audio clock counts the same eighths as playback would" {
  let clock = BeatClock::new(dotted_quarter_bpm=76)
  assert_eq(clock.eighths(), 0)
  clock.tick(0.789473)
  assert_eq(clock.eighths(), 2)
  clock.tick(0.000002)
  assert_eq(clock.eighths(), 3)
  clock.tick(-1.0)
  assert_eq(clock.eighths(), 3)
}
