///|
test "battery HUD formats runtime percentage and unknown reading" {
  inspect(battery_label(Some(82)), content="82%")
  inspect(battery_label(Some(0)), content="0%")
  inspect(battery_label(Some(100)), content="100%")
  inspect(battery_label(None), content="--%")
}

///|
/// TEST-ONLY reference renderer (R3A): the pre-optimization sampling
/// algorithm kept verbatim — one `ping_pong_x` call per destination pixel
/// with its modulo, positive-modulo wrap and transparency Option match.
/// It is the normative semantics of `draw_indexed_layer`; acceptance for
/// the optimized renderer is EXACT framebuffer equality against this, not
/// visual similarity. This is not a second production renderer and must
/// stay in this test file.
fn draw_indexed_layer_reference(
  canvas~ : @graphics.Canvas,
  layer~ : IndexedLayer,
  scroll_x~ : Int,
) -> Unit {
  let screen_width = canvas.width()
  let rows = canvas.height().min(layer.height)
  let layer_width = layer.width
  let palette = layer.palette
  let indices = layer.indices
  let transparent_index = layer.transparent_index
  for y in 0..<rows {
    let row = y * layer_width
    for x in 0..<screen_width {
      let index = indices[row + ping_pong_x(x + scroll_x, layer_width)].to_int()
      let skip = match transparent_index {
        Some(t) => index == t
        None => false
      }
      if skip {
        continue
      }
      canvas.pixel(x~, y~, color=palette[index])
    }
  }
}

///|
/// TEST-ONLY reference full-frame draw: `State::draw` with the reference
/// layer renderer substituted, sharing the sprite and battery HUD calls
/// (which R3A does not touch).
fn draw_state_reference(
  state : State,
  canvas~ : @graphics.Canvas,
  battery_percent~ : Int?,
) -> Unit {
  let scroll = state.scroll()
  draw_indexed_layer_reference(
    canvas~,
    layer=state.far_layer,
    scroll_x=far_scroll_offset(scroll),
  )
  draw_indexed_layer_reference(
    canvas~,
    layer=state.world_layer,
    scroll_x=scroll,
  )
  let sheet = state.walker_sheet
  canvas.sprite(
    sheet~,
    frame=state.walker_frame,
    x=FAIRY_X,
    y=(FAIRY_BASELINE_Y - sheet.frame_height()).max(0),
  )
  draw_indexed_layer_reference(
    canvas~,
    layer=state.foreground_layer,
    scroll_x=foreground_scroll_offset(scroll),
  )
  let battery_text = battery_label(battery_percent)
  canvas.text(
    text=battery_text,
    x=(canvas.width() - @graphics.text_width(text=battery_text) - 4).max(0),
    y=4,
    color=@core.Color::rgb(r=31, g=51, b=53),
  )
}

///|
/// RGB565-exact framebuffer comparison, pixel for pixel.
fn framebuffers_equal(a : @graphics.FrameView, b : @graphics.FrameView) -> Bool {
  if a.width() != b.width() || a.height() != b.height() {
    return false
  }
  let width = a.width()
  let row_a : FixedArray[Int] = FixedArray::make(width, -1)
  let row_b : FixedArray[Int] = FixedArray::make(width, -1)
  for y in 0..<a.height() {
    let _ = a.copy_rgb565_row(y~, out=row_a)
    let _ = b.copy_rgb565_row(y~, out=row_b)
    for x in 0..<width {
      if row_a[x] != row_b[x] {
        return false
      }
    }
  }
  true
}

///|
/// Draws one layer with both renderers on fresh canvases and asserts the
/// framebuffers are identical.
fn assert_layer_equivalence(
  layer~ : IndexedLayer,
  scroll_x~ : Int,
  width~ : Int,
  height~ : Int,
) -> Unit raise {
  let optimized = @graphics.Canvas::new(width~, height~)
  let reference = @graphics.Canvas::new(width~, height~)
  draw_indexed_layer(canvas=optimized, layer~, scroll_x~)
  draw_indexed_layer_reference(canvas=reference, layer~, scroll_x~)
  assert_true(
    framebuffers_equal(optimized.frame_view(), reference.frame_view()),
  )
}

///|
/// R3A acceptance: the optimized layer renderer produces EXACTLY the
/// reference framebuffer across the representative scroll matrix on all
/// three authored layers — opaque far mist, transparent world (the fairy's
/// road), transparent foreground — including the mirror-seam and
/// full-period boundaries of the 240-wide ping-pong ring and negative
/// scrolls, plus a clipped canvas size.
test "layer renderer is framebuffer-exact vs the reference across the scroll matrix" {
  let state = State::new()
  let scrolls = [0, 1, 119, 120, 239, 240, 241, 479, 480, -1, -120, -240]
  for scroll in scrolls {
    assert_layer_equivalence(
      layer=state.far_layer,
      scroll_x=scroll,
      width=120,
      height=160,
    )
    // The transparent layers: mirrored tiles and skipped samples.
    assert_layer_equivalence(
      layer=state.world_layer,
      scroll_x=scroll,
      width=120,
      height=160,
    )
    assert_layer_equivalence(
      layer=state.foreground_layer,
      scroll_x=scroll,
      width=120,
      height=160,
    )
    // Clipped canvas: exercises the row/width bounds on both paths.
    assert_layer_equivalence(
      layer=state.world_layer,
      scroll_x=scroll,
      width=64,
      height=80,
    )
  }
}

///|
/// R3A acceptance at the full-frame level: the production `State::draw`
/// framebuffer equals the reference full-frame draw for every fairy pose
/// (reached through production eighth indices) and every battery HUD
/// variant.
test "State::draw is framebuffer-exact vs the reference for poses and battery" {
  let batteries : Array[Int?] = [None, Some(0), Some(95), Some(100)]
  // Production eighth indices realizing poses 0..5 (floor(e*3/4) % 6).
  let pose_eighths = [0, 2, 3, 4, 6, 7]
  for e in pose_eighths {
    let state = State::new().update(musical_eighths=e)
    for battery in batteries {
      let optimized = @graphics.Canvas::new(width=120, height=160)
      let reference = @graphics.Canvas::new(width=120, height=160)
      state.draw(canvas=optimized, battery_percent=battery)
      draw_state_reference(state, canvas=reference, battery_percent=battery)
      assert_true(
        framebuffers_equal(optimized.frame_view(), reference.frame_view()),
      )
    }
  }
}

///|
/// R3A acceptance over production scroll values: scrolls the scene reaches
/// through real updates (floor(9k/16) for k updates) around the mirror and
/// period boundaries, at the 30 Hz cadence, compared frame for frame.
test "walking states draw framebuffer-exact vs the reference" {
  let mut state = State::new()
  let checkpoints = [0, 1, 2, 212, 214, 425, 427, 853, 854]
  let mut next = 0
  for k in 0..<855 {
    if k == checkpoints[next] {
      let optimized = @graphics.Canvas::new(width=120, height=160)
      let reference = @graphics.Canvas::new(width=120, height=160)
      state.draw(canvas=optimized, battery_percent=Some(76))
      draw_state_reference(state, canvas=reference, battery_percent=Some(76))
      assert_true(
        framebuffers_equal(optimized.frame_view(), reference.frame_view()),
      )
      if next < checkpoints.length() - 1 {
        next += 1
      }
    }
    state = state.update(musical_eighths=k % 8)
  }
}
