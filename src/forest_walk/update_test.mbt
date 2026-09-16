///|
test "ambient scene advances by nine sixteenth-pixels on every update" {
  let mut state = State::new()
  assert_eq(state.scroll(), 0)
  assert_eq(state.walker_frame(), 0)
  for frame in 1..<31 {
    state = state.update(musical_eighths=0)
    assert_eq(state.scroll(), frame * 9 / 16)
    assert_eq(state.frame(), frame)
  }
  // One second of 30 Hz frames: 270 sixteenth-pixels = 16.875 px -> 16.
  assert_eq(state.scroll(), 16)
}

///|
test "fairy pose spreads six frames across the eight-eighth 4/4 bar" {
  let mut state = State::new()
  for eighth in 0..<24 {
    state = state.update(musical_eighths=eighth)
    assert_eq(state.walker_frame(), eighth * 3 / 4 % 6)
    // The pose ignores the simulation frame counter entirely.
    assert_eq(state.frame(), eighth + 1)
  }
  // One pose lasts 4/3 eighths: the pose holds through eighths 1 and 2
  // (changes land at 0, 1 1/3, 2 2/3, 4, ...), and pose 0 returns exactly
  // on the bar line — the downbeat of every 4/4 bar.
  assert_eq(state.update(musical_eighths=8).walker_frame(), 0)
  assert_eq(state.update(musical_eighths=1).walker_frame(), 0)
  assert_eq(state.update(musical_eighths=2).walker_frame(), 1)
  assert_eq(state.update(musical_eighths=4).walker_frame(), 3)
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
  assert_eq(slow.walker_frame(), 3)
  assert_eq(fast.scroll(), 1)
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
  // The first whole pixel of scroll lands on the second update; the
  // sixteenth-pixel remainder is carried, not lost.
  assert_eq(next.scroll(), 0)
  assert_eq(
    State::new().update(musical_eighths=0).update(musical_eighths=0).scroll(),
    1,
  )
  assert_eq(next.walker_frame(), 1)
}
