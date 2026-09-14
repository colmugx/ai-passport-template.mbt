///|
test "music beat uses exact 76 BPM boundaries" {
  // One dotted-quarter beat at 76 BPM is 60/76 seconds; sample-derived
  // seconds keep the boundary values readable.
  assert_eq(music_beat(0.0, 76), 0)
  assert_eq(music_beat(12631.0 / 16000.0, 76), 0)
  assert_eq(music_beat(12632.0 / 16000.0, 76), 1)
  assert_eq(music_beat(25263.0 / 16000.0, 76), 1)
  assert_eq(music_beat(25264.0 / 16000.0, 76), 2)
  assert_eq(music_beat(30.0, 76), 38)
}

///|
test "music beat uses the supplied tempo and rejects bad input ranges" {
  assert_eq(music_beat(15999.0 / 16000.0, 60), 0)
  assert_eq(music_beat(1.0, 60), 1)
  assert_eq(music_beat(2.0, 120), 4)
  assert_eq(music_beat(-5.0, 120), 0)
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
