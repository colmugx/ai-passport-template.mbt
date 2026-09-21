///|
test "fairy sheet exposes six 28x32 frames and every frame draws" {
  let sheet = @forest_walk.State::new().walker_sheet()
  inspect(sheet.frame_count(), content="6")
  inspect(sheet.frame_width(), content="28")
  inspect(sheet.frame_height(), content="32")
  // Every frame renders cleanly on a plain canvas.
  let canvas = @graphics.Canvas::new(width=64, height=80)
  for frame in 0..<6 {
    canvas.sprite(sheet~, frame~, x=26, y=40)
  }
}

///|
test "fairy sheet keeps transparent pixels transparent in all six frames" {
  let sheet = @forest_walk.State::new().walker_sheet()
  let background = @core.Color::rgb(r=0, g=255, b=0).to_rgb565()
  for frame in 0..<6 {
    let canvas = @graphics.Canvas::new(width=28, height=32)
    canvas.clear(color=@core.Color::rgb(r=0, g=255, b=0))
    canvas.sprite(sheet~, frame~, x=0, y=0)
    let mut transparent = 0
    let mut opaque_count = 0
    for y in 0..<32 {
      let row = FixedArray::make(28, 0)
      assert_eq(canvas.frame_view().copy_rgb565_row(y~, out=row), 28)
      for pixel in row {
        if pixel == background {
          transparent += 1
        } else {
          opaque_count += 1
        }
      }
    }
    assert_true(transparent > 0)
    assert_true(opaque_count > 0)
  }
}

///|
test "draw survives repeated layer wraps while walking on both canvases" {
  let mut s = @forest_walk.State::new()
  // Continue beyond a full ping-pong tile period at the fixed scroll rate
  // (0.5625 pixels per update).
  for _ in 0..<500 {
    s = s.update(musical_eighths=0)
  }
  assert_eq(s.scroll(), 281)
  s.draw(canvas=@graphics.Canvas::logical(), battery_percent=Some(82))
  s.draw(
    canvas=@graphics.Canvas::new(width=64, height=80),
    battery_percent=None,
  )
}

///|
test "draw with a fresh state succeeds on the logical and a 64x80 canvas" {
  let state = @forest_walk.State::new()
  state.draw(canvas=@graphics.Canvas::logical(), battery_percent=Some(82))
  state.draw(
    canvas=@graphics.Canvas::new(width=64, height=80),
    battery_percent=None,
  )
}
