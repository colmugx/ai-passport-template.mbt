///|
test "draw runs clean on a small canvas, the logical canvas and a fairy-sized canvas" {
  let state = State::new()
  state.draw(
    canvas=@graphics.Canvas::new(width=64, height=80),
    battery_percent=None,
  )
  state.draw(canvas=@graphics.Canvas::logical(), battery_percent=Some(82))
  // The minimum interesting canvas: exactly fairy-sized.
  state.draw(
    canvas=@graphics.Canvas::new(width=28, height=32),
    battery_percent=None,
  )
}

///|
test "draw also handles walking and paused states" {
  let input = @input.InputState::new()
  input.press(@input.Up)
  let moving = State::new().update(input~, beat=1)
  moving.draw(canvas=@graphics.Canvas::logical(), battery_percent=Some(82))
  // Fresh input snapshot with a pause edge for the paused scene.
  let pause_input = @input.InputState::new()
  pause_input.press(@input.Ok)
  let paused = moving.update(input=pause_input, beat=2)
  assert_true(paused.paused())
  paused.draw(
    canvas=@graphics.Canvas::new(width=64, height=80),
    battery_percent=None,
  )
}

///|
test "battery HUD changes only the top-right pixels for known and unknown values" {
  let state = State::new()
  let known = @graphics.Canvas::logical()
  let unknown = @graphics.Canvas::logical()
  state.draw(canvas=known, battery_percent=Some(82))
  state.draw(canvas=unknown, battery_percent=None)
  let mut changed = false
  for y in 2..<7 {
    let a = FixedArray::make(120, 0)
    let b = FixedArray::make(120, 0)
    assert_eq(known.frame_view().copy_rgb565_row(y~, out=a), 120)
    assert_eq(unknown.frame_view().copy_rgb565_row(y~, out=b), 120)
    for x in 0..<120 {
      if a[x] != b[x] {
        assert_true(x >= 100)
        changed = true
      }
    }
  }
  assert_true(changed)
}
