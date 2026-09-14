///|
test "ambient scene advances by three quarter-pixels on every update" {
  let mut state = State::new()
  assert_eq(state.scroll(), 0)
  assert_eq(state.walker_frame(), 0)
  for frame in 1..<61 {
    state = state.update(musical_eighths=0)
    assert_eq(state.scroll(), frame * 3 / 4)
    assert_eq(state.frame(), frame)
  }
}

///|
test "fairy pose is the musical eighth index modulo six, independent of frames" {
  let mut state = State::new()
  for eighth in 0..<60 {
    state = state.update(musical_eighths=eighth)
    assert_eq(state.walker_frame(), eighth % 6)
    // The pose ignores the simulation frame counter entirely.
    assert_eq(state.frame(), eighth + 1)
  }
  // One full six-pose walk cycle per 6/8 bar: six eighths return to pose 0.
  assert_eq(state.update(musical_eighths=60).walker_frame(), 0)
  state = state.update(musical_eighths=7)
  assert_eq(state.walker_frame(), 1)
}

///|
test "walking poses never depend on scroll or frame history" {
  let state = State::new()
  let slow = state.update(musical_eighths=4)
  let fast = state
    .update(musical_eighths=4)
    .update(musical_eighths=4)
    .update(musical_eighths=4)
  // Same musical position means the same pose, whatever the frame count.
  assert_eq(slow.walker_frame(), fast.walker_frame())
  assert_eq(slow.walker_frame(), 4)
  assert_eq(fast.scroll(), 2)
  assert_eq(fast.frame(), 3)
}

///|
test "update returns a new snapshot without mutating the receiver" {
  let state = State::new()
  let next = state.update(musical_eighths=2)
  assert_eq(state.frame(), 0)
  assert_eq(state.scroll(), 0)
  assert_eq(state.walker_frame(), 0)
  assert_eq(next.frame(), 1)
  // The first whole pixel of scroll lands on the fourth update; the
  // quarter-pixel remainder is carried, not lost.
  assert_eq(next.scroll(), 0)
  assert_eq(
    State::new()
    .update(musical_eighths=0)
    .update(musical_eighths=0)
    .update(musical_eighths=0)
    .update(musical_eighths=0)
    .scroll(),
    3,
  )
  assert_eq(next.walker_frame(), 2)
}
