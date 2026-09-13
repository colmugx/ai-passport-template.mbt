///|
/// The host frame loop consumes input edges and supplies a transport snapshot.
fn step(state : State, input : @input.InputState, beat : Int) -> State {
  let next = state.update(input~, beat~)
  input.advance()
  next
}

///|
fn tap(
  state : State,
  input : @input.InputState,
  button : @input.Button,
  beat : Int,
) -> State {
  input.press(button)
  step(state, input, beat)
}

///|
test "default scene scrolls on its first unpaused frame" {
  let input = @input.InputState::new()
  let state = State::new()
  assert_eq(state.speed().level, 1)
  let next = step(state, input, 0)
  assert_eq(next.scroll(), 1)
  assert_eq(next.frame(), 1)
}

///|
test "Up and Down clamp speed to 0 through 3" {
  let input = @input.InputState::new()
  let s2 = tap(State::new(), input, @input.Up, 0)
  let s3 = tap(s2, input, @input.Up, 0)
  assert_eq(s3.speed().level, 3)
  assert_eq(tap(s3, input, @input.Up, 0).speed().level, 3)
  let s0 = tap(
    tap(tap(s3, input, @input.Down, 0), input, @input.Down, 0),
    input,
    @input.Down,
    0,
  )
  assert_eq(s0.speed().level, 0)
  assert_eq(tap(s0, input, @input.Down, 0).speed().level, 0)
  let still = step(s0, input, 1)
  assert_eq(still.scroll(), s0.scroll())
  assert_eq(still.walker_frame(), s0.walker_frame())
}

///|
test "Ok toggles pause on an input edge and freezes scene motion" {
  let input = @input.InputState::new()
  let started = step(State::new(), input, 1)
  assert_eq(started.walker_frame(), 1)
  let paused = tap(started, input, @input.Ok, 2)
  assert_true(paused.paused())
  assert_eq(paused.scroll(), started.scroll())
  assert_eq(paused.walker_frame(), started.walker_frame())
  let held = step(paused, input, 3)
  assert_true(held.paused())
  assert_eq(held.frame(), paused.frame() + 1)
  assert_eq(held.walker_frame(), 1)
  let faster = tap(held, input, @input.Up, 3)
  assert_eq(faster.speed().level, 2)
  assert_eq(faster.scroll(), held.scroll())
  let resumed = tap(faster, input, @input.Ok, 3)
  assert_false(resumed.paused())
  assert_eq(resumed.walker_frame(), 3)
  assert_eq(resumed.scroll(), faster.scroll() + 2)
}

///|
test "frame update uses the supplied beat without advancing audio transport" {
  let input = @input.InputState::new()
  let state = State::new()
  let player = @audio.Player::new(song=state.song())
  let mut next = state
  for _ in 0..<40 {
    next = step(next, input, player.beat())
  }
  assert_eq(player.position_ticks(), 0)
  assert_eq(player.beat(), 0)
  assert_eq(next.scroll(), 40)
  assert_eq(next.walker_frame(), 0)
  // Only an explicit audio callback render can move the external player.
  player.render(out=FixedArray::make(16000, 0))
  assert_true(player.position_ticks() > 0)
  let after_audio = step(next, input, player.beat())
  assert_eq(after_audio.walker_frame(), player.beat() % 4)
}

///|
test "update returns a new snapshot without mutating the receiver" {
  let input = @input.InputState::new()
  let state = State::new()
  input.press(@input.Up)
  input.press(@input.Ok)
  let next = state.update(input~, beat=2)
  assert_eq(state.frame(), 0)
  assert_eq(state.speed().level, 1)
  assert_false(state.paused())
  assert_eq(state.scroll(), 0)
  assert_eq(next.frame(), 1)
  assert_eq(next.speed().level, 2)
  assert_true(next.paused())
  assert_eq(next.scroll(), 0)
}
