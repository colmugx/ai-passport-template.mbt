///|
test "microsecond positions map to eighth indices at 76 BPM" {
  // One dotted-quarter beat at 76 BPM is 60/76 s = 789473.68 us; one beat
  // is three eighths, one 6/8 bar is six.
  assert_eq(musical_eighths_from_us(0L, 76), 0)
  assert_eq(musical_eighths_from_us(263157L, 76), 0)
  assert_eq(musical_eighths_from_us(263158L, 76), 1)
  assert_eq(musical_eighths_from_us(789473L, 76), 2)
  assert_eq(musical_eighths_from_us(789474L, 76), 3)
  assert_eq(musical_eighths_from_us(1578947L, 76), 5)
  assert_eq(musical_eighths_from_us(1578948L, 76), 6)
  assert_eq(musical_eighths_from_us(60000000L, 76), 228)
}

///|
test "eighth conversion scales with tempo and clamps bad ranges" {
  assert_eq(musical_eighths_from_us(10000000L, 60), 30)
  assert_eq(musical_eighths_from_us(10000000L, 120), 60)
  assert_eq(musical_eighths_from_us(-1L, 76), 0)
}

///|
test "fairy pose clock leads the playback position by the measured 100 ms" {
  assert_eq(fairy_pose_position_us(0L), 100000L)
  assert_eq(fairy_pose_position_us(263157L), 363157L)
  // 163158 us is mid-first-eighth raw, but the lead crosses the boundary:
  // the pose advances earlier, which is what the hardware measurement asked
  // for.
  assert_eq(musical_eighths_from_us(163158L, 76), 0)
  assert_eq(musical_eighths_from_us(fairy_pose_position_us(163158L), 76), 1)
}

///|
test "host stub holds the music position at the track start" {
  // No audio hardware is attached to hosts, so the walk clock reads pose 0
  // (the 100 ms lead alone does not cross the first eighth boundary).
  assert_eq(device_musical_eighths(), 0)
}
