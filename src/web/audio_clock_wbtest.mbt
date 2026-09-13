///|
test "playback beat uses exact 76 BPM sample boundary" {
  assert_eq(playback_beat(0L, 76), 0)
  assert_eq(playback_beat(12631L, 76), 0)
  assert_eq(playback_beat(12632L, 76), 1)
  assert_eq(playback_beat(25263L, 76), 1)
  assert_eq(playback_beat(25264L, 76), 2)
  assert_eq(playback_beat(480000L, 76), 38)
}

///|
test "playback beat uses the supplied song tempo" {
  assert_eq(playback_beat(15999L, 60), 0)
  assert_eq(playback_beat(16000L, 60), 1)
  assert_eq(playback_beat(32000L, 120), 4)
}

///|
test "pause and visibility gate cannot request another Player chunk" {
  assert_true(should_schedule_chunk(true, false, false, 1.0, 1.12))
  assert_false(should_schedule_chunk(true, true, false, 1.0, 1.12))
  assert_false(should_schedule_chunk(true, false, true, 1.0, 1.12))
  assert_false(should_schedule_chunk(false, false, false, 1.0, 1.12))
  assert_false(should_schedule_chunk(true, false, false, 1.12, 1.12))
}

///|
test "playback head follows scheduled audio and freezes at queue end" {
  let timeline = PlaybackTimeline::new()
  assert_false(timeline.prepare(10.0))
  assert_eq(timeline.first_audio_start_time, 10.02)
  timeline.mark_scheduled()
  assert_eq(timeline.played_samples(10.0), 0L)
  assert_eq(timeline.played_samples(10.036), 256L)
  assert_eq(timeline.played_samples(10.1), 512L)
  assert_true(timeline.prepare(10.1))
  assert_eq(timeline.played_samples(10.1), 512L)
  timeline.mark_scheduled()
  assert_eq(timeline.played_samples(10.136), 768L)
}
