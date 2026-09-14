///|
test "ambient scene advances by one pixel on every update" {
  let mut state = State::new()
  assert_eq(state.scroll(), 0)
  assert_eq(state.walker_frame(), 0)
  for frame in 1..<61 {
    state = state.update(beat=0)
    assert_eq(state.scroll(), frame)
    assert_eq(state.frame(), frame)
    assert_eq(state.walker_frame(), frame / 4 % 6)
  }
}

///|
test "walking visits all six fairy poses every 24 simulation frames" {
  let mut state = State::new()
  let seen = FixedArray::make(6, false)
  for frame in 1..<25 {
    state = state.update(beat=999)
    let pose = state.walker_frame()
    assert_true(pose >= 0 && pose < 6)
    seen[pose] = true
    assert_eq(pose, frame / 4 % 6)
  }
  for present in seen {
    assert_true(present)
  }
  assert_eq(state.walker_frame(), 0)
}

///|
test "frame update does not advance audio transport" {
  let state = State::new()
  let player = @audio.Player::new(song=state.song())
  let mut next = state
  for _ in 0..<40 {
    next = next.update(beat=player.beat())
  }
  assert_eq(player.position_ticks(), 0)
  assert_eq(player.beat(), 0)
  assert_eq(next.scroll(), 40)
  assert_eq(next.walker_frame(), 4)
  // Only an explicit audio callback render moves the external player.
  player.render(out=FixedArray::make(16000, 0))
  assert_true(player.position_ticks() > 0)
  let after_audio = next.update(beat=player.beat())
  assert_eq(after_audio.walker_frame(), 4)
  assert_eq(next.update(beat=0).walker_frame(), after_audio.walker_frame())
}

///|
test "update returns a new snapshot without mutating the receiver" {
  let state = State::new()
  let next = state.update(beat=2)
  assert_eq(state.frame(), 0)
  assert_eq(state.scroll(), 0)
  assert_eq(state.walker_frame(), 0)
  assert_eq(next.frame(), 1)
  assert_eq(next.scroll(), 1)
  assert_eq(next.walker_frame(), 0)
}
