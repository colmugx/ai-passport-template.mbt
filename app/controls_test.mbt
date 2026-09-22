///|
test "startup volume is 80 and audible" {
  let app = @app.App::new()
  inspect(app.volume(), content="80")
  inspect(app.muted(), content="false")
}

///|
test "volume clamps to 0..100 in steps of 10" {
  let app = @app.App::new()
  // UP four times from 80: 90, 100, 100, 100 — clamped, never above.
  for _ in 0..<4 {
    app.input(Up, true)
    app.advance(step_now(), playback_position_us=1_000_000L)
    app.input(Up, false)
    app.advance(step_now(), playback_position_us=1_000_000L)
  }
  inspect(app.volume(), content="100")
  // DOWN eleven times from 100: floors at 0.
  for i in 0..<11 {
    app.input(Down, true)
    app.advance(now_us(i + 100), playback_position_us=1_000_000L)
    app.input(Down, false)
    app.advance(now_us(i + 101), playback_position_us=1_000_000L)
  }
  inspect(app.volume(), content="0")
  // From the floor, DOWN stays at 0; UP climbs again.
  app.input(Down, true)
  app.advance(now_us(200), playback_position_us=1_000_000L)
  app.input(Down, false)
  app.advance(now_us(201), playback_position_us=1_000_000L)
  inspect(app.volume(), content="0")
  app.input(Up, true)
  app.advance(now_us(202), playback_position_us=1_000_000L)
  app.input(Up, false)
  app.advance(now_us(203), playback_position_us=1_000_000L)
  inspect(app.volume(), content="10")
}

///|
test "one press edge produces exactly one semantic action" {
  let app = @app.App::new()
  app.input(Up, true)
  app.advance(now_us(1), playback_position_us=1_000_000L)
  inspect(app.volume(), content="90")
  // Held down across many frames: no auto-repeat, still one action.
  for i in 2..<=6 {
    app.advance(now_us(i), playback_position_us=1_000_000L)
  }
  inspect(app.volume(), content="90")
  // Release contributes nothing.
  app.input(Up, false)
  app.advance(now_us(7), playback_position_us=1_000_000L)
  inspect(app.volume(), content="90")
  // A second full press edge acts again.
  app.input(Up, true)
  app.advance(now_us(8), playback_position_us=1_000_000L)
  app.input(Up, false)
  app.advance(now_us(9), playback_position_us=1_000_000L)
  inspect(app.volume(), content="100")
}

///|
test "mute remembers volume; only OK clears it" {
  let app = @app.App::new()
  app.input(Ok, true)
  app.advance(now_us(1), playback_position_us=1_000_000L)
  app.input(Ok, false)
  app.advance(now_us(2), playback_position_us=1_000_000L)
  inspect(app.muted(), content="true")
  inspect(app.volume(), content="80")
  // UP while muted changes the remembered volume but stays muted.
  app.input(Up, true)
  app.advance(now_us(3), playback_position_us=1_000_000L)
  app.input(Up, false)
  app.advance(now_us(4), playback_position_us=1_000_000L)
  inspect(app.volume(), content="90")
  inspect(app.muted(), content="true")
  // DOWN while muted also only changes the remembered volume.
  app.input(Down, true)
  app.advance(now_us(5), playback_position_us=1_000_000L)
  app.input(Down, false)
  app.advance(now_us(6), playback_position_us=1_000_000L)
  inspect(app.volume(), content="80")
  inspect(app.muted(), content="true")
  // OK again restores the remembered volume audibly.
  app.input(Ok, true)
  app.advance(now_us(7), playback_position_us=1_000_000L)
  app.input(Ok, false)
  app.advance(now_us(8), playback_position_us=1_000_000L)
  inspect(app.muted(), content="false")
  inspect(app.volume(), content="80")
}

///|
test "draw presents a changing logical frame" {
  let app = @app.App::new()
  app.draw(battery_percent=Some(82))
  let first = frame_digest(app.frame_view())
  // The first tick establishes the baseline; one second of simulation
  // after it changes the rendered scene.
  app.advance(0L)
  app.advance(1_000_000L)
  app.draw(battery_percent=Some(82))
  let second = frame_digest(app.frame_view())
  guard first != second else {
    fail("frame did not change after a second of simulation")
  }
}

///|
/// Cheap change detector over a frame view: sums RGB565 rows.
fn frame_digest(view : @graphics.FrameView) -> Int {
  let row : FixedArray[Int] = FixedArray::make(view.width(), 0)
  let mut digest = 0
  for y in 0..<view.height() {
    let n = view.copy_rgb565_row(y~, out=row)
    for i in 0..<n {
      digest += row[i]
    }
  }
  digest
}

///|
/// Monotonic test clock helpers: unique increasing timestamps so the
/// accumulator never rewinds between input edges.
fn now_us(tick : Int) -> Int64 {
  tick.to_int64() * 1_000_000L
}

///|
fn step_now() -> Int64 {
  now_us(500)
}
