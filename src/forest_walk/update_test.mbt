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
test "frame update is independent of the audible beat value" {
  let state = State::new()
  let mut with_beats = state
  let mut without_beats = state
  for beat in 0..<40 {
    with_beats = with_beats.update(beat~)
    without_beats = without_beats.update(beat=0)
  }
  // The pose follows the simulation frame counter only; beat snapshots ride
  // along for a future audible phase and never alter the walk.
  assert_eq(with_beats.scroll(), 40)
  assert_eq(with_beats.walker_frame(), 4)
  assert_eq(with_beats.frame(), without_beats.frame())
  assert_eq(with_beats.scroll(), without_beats.scroll())
  assert_eq(with_beats.walker_frame(), without_beats.walker_frame())
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
