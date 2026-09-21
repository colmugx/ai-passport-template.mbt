///|
test "State::new starts an ambient scene with the walk-clock tempo" {
  let state = @forest_walk.State::new()
  inspect(state.frame(), content="0")
  inspect(state.scroll(), content="0")
  inspect(state.walker_frame(), content="0")
  // Music is a runtime-owned file asset; the application keeps only the
  // visual cadence constant. No SDK song/player type is involved.
  inspect(@forest_walk.MUSIC_DOTTED_QUARTER_BPM, content="76")
  assert_true(@forest_walk.MUSIC_DOTTED_QUARTER_BPM > 0)
}
