// Whitebox tests: they use the package-private generated-layer builders and
// the package-private renderer, and construct State records directly to pin
// down exact scroll offsets.

///|
fn count_transparent_samples(layer : @generated.IndexedLayer) -> Int {
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
test "generated scenery layers are 240x160 with compact palettes" {
  let far = build_forest_far_layer()
  let world = build_forest_world_layer()
  let foreground = build_forest_foreground_layer()
  debug_inspect((far.width, far.height), content="(240, 160)")
  debug_inspect((world.width, world.height), content="(240, 160)")
  debug_inspect((foreground.width, foreground.height), content="(240, 160)")
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
  let layer : @generated.IndexedLayer = {
    width: 3,
    height: 2,
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
  let layer : @generated.IndexedLayer = {
    width: 2,
    height: 1,
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
  let row = FixedArray::make(120, 0)
  // Right of the fairy and below the HUD, the scene is exactly the layer
  // stack: opaque foreground wins, otherwise the world layer, otherwise the
  // far layer through the world's transparent gaps. Each assertion also
  // verifies that layer's scroll offset.
  let mut world_verified = 0
  let mut foreground_verified = 0
  for y in 12..<158 {
    assert_eq(canvas.frame_view().copy_rgb565_row(y~, out=row), 120)
    for x in 60..<118 {
      let fg_index = foreground.indices[y * 240 +
        ping_pong_x(x + foreground_offset, 240)]
      if fg_index.to_int() != 0 {
        assert_eq(row[x], foreground.palette[fg_index.to_int()].to_rgb565())
        foreground_verified += 1
      } else {
        let world_index = world.indices[y * 240 + ping_pong_x(x + scroll, 240)]
        if world_index.to_int() != 0 {
          assert_eq(row[x], world.palette[world_index.to_int()].to_rgb565())
          world_verified += 1
        } else {
          let far_index = far.indices[y * 240 +
            ping_pong_x(x + far_scroll_offset(scroll), 240)]
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
    canvas.sprite(sheet~, frame=2, x=FAIRY_X, y=FAIRY_BASELINE_Y - 32)
    let mut min_x = 120
    let mut max_x = -1
    let mut min_y = 160
    let mut max_y = -1
    let row = FixedArray::make(120, 0)
    for y in 0..<160 {
      assert_eq(canvas.frame_view().copy_rgb565_row(y~, out=row), 120)
      for x in 0..<120 {
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
  assert_true(min_x >= FAIRY_X && max_x < FAIRY_X + 28)
  assert_true(min_y >= FAIRY_BASELINE_Y - 32 && max_y < FAIRY_BASELINE_Y)
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
