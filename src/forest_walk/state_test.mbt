///|
test "State::new starts an ambient scene with a four-voice 6/8 song" {
  let state = State::new()
  inspect(state.frame(), content="0")
  inspect(state.scroll(), content="0")
  inspect(state.walker_frame(), content="0")
  // The song is an immutable snapshot: only read accessors cross the SDK
  // boundary (the structural per-track checks live in state_wbtest.mbt).
  let song = state.song()
  inspect(song.track_count(), content="4")
  inspect(song.meter().numerator, content="6")
  inspect(song.meter().denominator, content="8")
}
