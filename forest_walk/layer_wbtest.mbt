// Whitebox tests: they use the package-private generated-layer builders and
// the package-private renderer, and construct State records directly to pin
// down exact scroll offsets.

///|
fn count_transparent_samples(layer : IndexedLayer) -> Int {
  guard layer.transparent_index is Some(t) else { return 0 }
  let mut count = 0
  for index in layer.indices {
    if index.to_int() == t {
      count += 1
    }
  }
  count
}

///|
test "generated scenery layers are 120x160 samples presented at 2x" {
  let far = build_forest_far_layer()
  let world = build_forest_world_layer()
  let foreground = build_forest_foreground_layer()
  debug_inspect((far.width, far.height, far.scale), content="(120, 160, 2)")
  debug_inspect(
    (world.width, world.height, world.scale),
    content="(120, 160, 2)",
  )
  debug_inspect(
    (foreground.width, foreground.height, foreground.scale),
    content="(120, 160, 2)",
  )
  assert_eq(far.indices.length(), 19200)
  assert_eq(world.indices.length(), 19200)
  assert_eq(foreground.indices.length(), 19200)
  // At most 128 opaque colors; transparent layers reserve index 0.
  assert_true(far.palette.length() <= 128)
  assert_true(world.palette.length() <= 129)
  assert_true(foreground.palette.length() <= 129)
}

///|
test "far layer is fully opaque, world and foreground carry transparency" {
  let far = build_forest_far_layer()
  let world = build_forest_world_layer()
  let foreground = build_forest_foreground_layer()
  assert_true(far.transparent_index is None)
  assert_true(world.transparent_index is Some(0))
  assert_true(foreground.transparent_index is Some(0))
  inspect(count_transparent_samples(far), content="0")
  assert_true(count_transparent_samples(world) > 0)
  assert_true(count_transparent_samples(foreground) > 0)
}

///|
test "transparent samples leave the destination pixel untouched" {
  // 3x2 layer with index 0 reserved: row 0 = red, gap, blue;
  // row 1 = blue, blue, gap.
  let layer : IndexedLayer = {
    width: 3,
    height: 2,
    scale: 1,
    palette: FixedArray::from_array([
      @core.Color::rgb(r=255, g=0, b=255), // reserved slot, never sampled
      @core.Color::rgb(r=255, g=0, b=0),
      @core.Color::rgb(r=0, g=0, b=255),
    ]),
    indices: FixedArray::from_array([1, 0, 2, 2, 2, 0]),
    transparent_index: Some(0),
  }
  let canvas = @graphics.Canvas::new(width=3, height=2)
  let background = @core.Color::rgb(r=0, g=255, b=0)
  canvas.clear(color=background)
  draw_indexed_layer(canvas~, layer~, scroll_x=0)
  let expected = [
    FixedArray::from_array([
      @core.Color::rgb(r=255, g=0, b=0).to_rgb565(),
      background.to_rgb565(),
      @core.Color::rgb(r=0, g=0, b=255).to_rgb565(),
    ]),
    FixedArray::from_array([
      @core.Color::rgb(r=0, g=0, b=255).to_rgb565(),
      @core.Color::rgb(r=0, g=0, b=255).to_rgb565(),
      background.to_rgb565(),
    ]),
  ]
  for y in 0..<2 {
    let row = FixedArray::make(3, 0)
    assert_eq(canvas.frame_view().copy_rgb565_row(y~, out=row), 3)
    for x in 0..<3 {
      assert_eq(row[x], expected[y][x])
    }
  }
}

///|
test "renderer samples the mirrored tile past the layer width" {
  // 2x1 layer: [red, blue]. World x 2 and 3 land in the mirror, sampling
  // blue then red, so a scroll of 2 swaps the two on-screen pixels without
  // any mirrored copy in the data.
  let layer : IndexedLayer = {
    width: 2,
    height: 1,
    scale: 1,
    palette: FixedArray::from_array([
      @core.Color::rgb(r=255, g=0, b=0),
      @core.Color::rgb(r=0, g=0, b=255),
    ]),
    indices: FixedArray::from_array([0, 1]),
    transparent_index: None,
  }
  let canvas = @graphics.Canvas::new(width=2, height=1)
  draw_indexed_layer(canvas~, layer~, scroll_x=2)
  let row = FixedArray::make(2, 0)
  assert_eq(canvas.frame_view().copy_rgb565_row(y=0, out=row), 2)
  assert_eq(row[0], @core.Color::rgb(r=0, g=0, b=255).to_rgb565())
  assert_eq(row[1], @core.Color::rgb(r=255, g=0, b=0).to_rgb565())
}

///|
/// Builds a scene record at an exact scroll, so scroll-dependent rendering
/// is testable without driving the ambient frame loop.
fn state_at_scroll(scroll~ : Int, walker_frame~ : Int) -> State {
  {
    frame: 1,
    scroll_sixteenth: scroll * SUBPIXEL_UNITS_PER_PIXEL,
    walker_frame,
    walker_sheet: build_fairy_walk_right_sheet(),
    far_layer: build_forest_far_layer(),
    world_layer: build_forest_world_layer(),
    foreground_layer: build_forest_foreground_layer(),
  }
}

///|
test "scene renders every layer at its own scroll offset" {
  let scroll = 37
  let far = build_forest_far_layer()
  let world = build_forest_world_layer()
  let foreground = build_forest_foreground_layer()
  let canvas = @graphics.Canvas::logical()
  state_at_scroll(scroll~, walker_frame=1).draw(canvas~, battery_percent=None)
  let foreground_offset = foreground_scroll_offset(scroll)
  let row = FixedArray::make(canvas.width(), 0)
  // Right of the fairy and below the HUD, the scene is exactly the layer
  // stack: opaque foreground wins, otherwise the world layer, otherwise the
  // far layer through the world's transparent gaps. Each assertion also
  // verifies that layer's scroll offset.
  let mut world_verified = 0
  let mut foreground_verified = 0
  for y in 16..<(canvas.height() - 2) {
    assert_eq(canvas.frame_view().copy_rgb565_row(y~, out=row), canvas.width())
    for x in ((FAIRY_X + 28) * 2 + 4)..<(canvas.width() - 2) {
      let fg_x = ping_pong_x(
        x / foreground.scale + foreground_offset,
        foreground.width,
      )
      let fg_y = y / foreground.scale
      let fg_index = foreground.indices[fg_y * foreground.width + fg_x]
      if fg_index.to_int() != 0 {
        assert_eq(row[x], foreground.palette[fg_index.to_int()].to_rgb565())
        foreground_verified += 1
      } else {
        let world_x = ping_pong_x(
          x / world.scale + scroll,
          world.width,
        )
        let world_y = y / world.scale
        let world_index = world.indices[world_y * world.width + world_x]
        if world_index.to_int() != 0 {
          assert_eq(row[x], world.palette[world_index.to_int()].to_rgb565())
          world_verified += 1
        } else {
          let far_x = ping_pong_x(
            x / far.scale + far_scroll_offset(scroll),
            far.width,
          )
          let far_y = y / far.scale
          let far_index = far.indices[far_y * far.width + far_x]
          assert_eq(row[x], far.palette[far_index.to_int()].to_rgb565())
        }
      }
    }
  }
  assert_true(world_verified > 500)
  assert_true(foreground_verified > 500)
}

///|
test "fairy stays fixed in screen space while the world scrolls" {
  // A fairy pink that none of the quantized scenery palettes contains, so
  // signature pixels can only come from the sprite. The guard re-checks the
  // assumption so the test fails loudly if the assets change.
  let signature = @core.Color::rgb(r=238, g=165, b=227).to_rgb565()
  for
    layer in [
      build_forest_far_layer(),
      build_forest_world_layer(),
      build_forest_foreground_layer(),
    ] {
    for color in layer.palette {
      assert_false(color.to_rgb565() == signature)
    }
  }
  // Draws the scene stack without the foreground layer, so no occluder can
  // hide part of the fairy and the bounds stay exact.
  fn fairy_only_bounds(scroll : Int) -> (Int, Int, Int, Int) raise {
    let canvas = @graphics.Canvas::logical()
    draw_indexed_layer(
      canvas~,
      layer=build_forest_far_layer(),
      scroll_x=far_scroll_offset(scroll),
    )
    draw_indexed_layer(
      canvas~,
      layer=build_forest_world_layer(),
      scroll_x=scroll,
    )
    let sheet = build_fairy_walk_right_sheet()
    let frame_base = 2 * sheet.frame_width * sheet.frame_height
    for sy in 0..<sheet.frame_height {
      for sx in 0..<sheet.frame_width {
        let index = sheet.indices[
          frame_base + sy * sheet.frame_width + sx
        ].to_int()
        match sheet.palette[index] {
          Some(color) =>
            draw_design_pixel(
              canvas,
              FAIRY_X + sx,
              FAIRY_BASELINE_Y - 32 + sy,
              color,
            )
          None => ()
        }
      }
    }
    let mut min_x = canvas.width()
    let mut max_x = -1
    let mut min_y = canvas.height()
    let mut max_y = -1
    let row = FixedArray::make(canvas.width(), 0)
    for y in 0..<canvas.height() {
      assert_eq(
        canvas.frame_view().copy_rgb565_row(y~, out=row),
        canvas.width(),
      )
      for x in 0..<canvas.width() {
        if row[x] == signature {
          if x < min_x {
            min_x = x
          }
          if x > max_x {
            max_x = x
          }
          if y < min_y {
            min_y = y
          }
          if y > max_y {
            max_y = y
          }
        }
      }
    }
    (min_x, min_y, max_x, max_y)
  }
  // 96 world pixels of travel displace every layer but not the fairy.
  assert_eq(fairy_only_bounds(0), fairy_only_bounds(96))
  let (min_x, min_y, max_x, max_y) = fairy_only_bounds(0)
  assert_true(min_x >= FAIRY_X * 2 && max_x < (FAIRY_X + 28) * 2)
  assert_true(
    min_y >= (FAIRY_BASELINE_Y - 32) * 2 &&
    max_y < FAIRY_BASELINE_Y * 2,
  )
  assert_true(max_x - min_x > 4 && max_y - min_y > 8)
}

///|
test "ambient frame loop advances every parallax offset at fixed ratios" {
  let mut state = State::new()
  for frame in 1..<81 {
    state = state.update(musical_eighths=0)
    let scroll = frame * 9 / 16
    assert_eq(state.scroll(), scroll)
    assert_eq(far_scroll_offset(state.scroll()), scroll / 8)
    assert_eq(foreground_scroll_offset(state.scroll()), scroll * 3 / 2)
  }
}
