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
test "draw handles continuously walking states" {
  let moving = State::new().update(beat=1).update(beat=2)
  assert_eq(moving.scroll(), 2)
  moving.draw(canvas=@graphics.Canvas::logical(), battery_percent=Some(82))
  moving.draw(
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
  for y in 4..<11 {
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

///|
test "battery HUD leaves the top-right four by four corner untouched" {
  let state = State::new()
  let without_hud = @graphics.Canvas::logical()
  let with_hud = @graphics.Canvas::logical()
  state.draw(canvas=without_hud, battery_percent=None)
  state.draw(canvas=with_hud, battery_percent=Some(82))
  for y in 0..<4 {
    let a = FixedArray::make(120, 0)
    let b = FixedArray::make(120, 0)
    assert_eq(without_hud.frame_view().copy_rgb565_row(y~, out=a), 120)
    assert_eq(with_hud.frame_view().copy_rgb565_row(y~, out=b), 120)
    for x in 116..<120 {
      assert_eq(a[x], b[x])
    }
  }
}
