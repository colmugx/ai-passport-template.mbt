///|
test "draw runs clean on a small canvas, the logical canvas and a fairy-sized canvas" {
  let state = @forest_walk.State::new()
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
  let moving = @forest_walk.State::new()
    .update(musical_eighths=1)
    .update(musical_eighths=2)
  assert_eq(moving.scroll(), 1)
  moving.draw(canvas=@graphics.Canvas::logical(), battery_percent=Some(82))
  moving.draw(
    canvas=@graphics.Canvas::new(width=64, height=80),
    battery_percent=None,
  )
}

///|
test "battery HUD changes only the top-right pixels for known and unknown values" {
  let state = @forest_walk.State::new()
  let known = @graphics.Canvas::logical()
  let unknown = @graphics.Canvas::logical()
  state.draw(canvas=known, battery_percent=Some(82))
  state.draw(canvas=unknown, battery_percent=None)
  let width = known.width()
  let leftmost = (120 - design_text_width("82%") - 2) * 2
  let mut changed = false
  for y in 4..<14 {
    let a = FixedArray::make(width, 0)
    let b = FixedArray::make(width, 0)
    assert_eq(known.frame_view().copy_rgb565_row(y~, out=a), width)
    assert_eq(unknown.frame_view().copy_rgb565_row(y~, out=b), width)
    for x in 0..<width {
      if a[x] != b[x] {
        assert_true(x >= leftmost)
        changed = true
      }
    }
  }
  assert_true(changed)
}

///|
test "battery HUD anchors exactly four logical pixels from the right edge" {
  let state = @forest_walk.State::new()
  let with_hud = @graphics.Canvas::logical()
  let without_hud = @graphics.Canvas::logical()
  state.draw(canvas=with_hud, battery_percent=Some(82))
  state.draw(canvas=without_hud, battery_percent=None)
  // "--%" and "82%" occupy the same 120x160 design width. The HUD anchor is
  // two design pixels from the right edge, then the whole glyph is presented
  // at 2x on the 240x320 Canvas.
  assert_eq(design_text_width("--%"), design_text_width("82%"))
  let width = with_hud.width()
  let anchor = (120 - design_text_width("82%") - 2) * 2
  let mut leftmost = -1
  for y in 4..<14 {
    let a = FixedArray::make(width, 0)
    let b = FixedArray::make(width, 0)
    assert_eq(with_hud.frame_view().copy_rgb565_row(y~, out=a), width)
    assert_eq(without_hud.frame_view().copy_rgb565_row(y~, out=b), width)
    for x in 0..<width {
      if a[x] != b[x] {
        assert_true(x >= anchor)
        if leftmost < 0 || x < leftmost {
          leftmost = x
        }
      }
    }
  }
  assert_eq(leftmost, anchor)
}

///|
test "battery HUD leaves the top-right four by four corner untouched" {
  let state = @forest_walk.State::new()
  let without_hud = @graphics.Canvas::logical()
  let with_hud = @graphics.Canvas::logical()
  state.draw(canvas=without_hud, battery_percent=None)
  state.draw(canvas=with_hud, battery_percent=Some(82))
  let width = with_hud.width()
  for y in 0..<4 {
    let a = FixedArray::make(width, 0)
    let b = FixedArray::make(width, 0)
    assert_eq(without_hud.frame_view().copy_rgb565_row(y~, out=a), width)
    assert_eq(with_hud.frame_view().copy_rgb565_row(y~, out=b), width)
    for x in (width - 4)..<width {
      assert_eq(a[x], b[x])
    }
  }
}
