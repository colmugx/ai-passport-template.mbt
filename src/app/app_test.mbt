///|
/// One logical step is exactly 1/30 s of accumulated time, and host calls
/// at other rates see the same cadence through the accumulator.
test "fixed-step cadence at 30 Hz" {
  let app = @app.App::new()
  inspect(app.frame(), content="0")
  // The first tick only establishes the host time baseline.
  let mut now = 0L
  app.advance(now)
  // A 30 Hz host pacing whole 1/30 s ticks: one step per tick (33334 us
  // ticks bank a 20 us remainder that never buys an extra step).
  for _ in 0..<30 {
    now += 33334L
    app.advance(now)
  }
  inspect(app.frame(), content="30")
  // The same second as 60 Hz rAF ticks (16667 us): identical cadence.
  let start = app.frame()
  for _ in 0..<60 {
    now += 16667L
    app.advance(now)
  }
  inspect(app.frame() - start, content="30")
  // A stalled host waking with a huge delta: catch-up is capped at 5 steps.
  let capped = app.frame()
  now += 10_000_000L
  app.advance(now)
  inspect(app.frame() - capped, content="5")
  // Equal or earlier timestamps never rewind the clock.
  let frozen = app.frame()
  app.advance(now)
  app.advance(-1L)
  inspect(app.frame(), content="\{frozen}")
}

///|
test "scroll advances at 22.5 logical px/s" {
  let app = @app.App::new()
  let mut now = 0L
  // Establish the baseline: the first tick simulates no pre-boot time.
  app.advance(now)
  // One second of simulation: 30 steps = 90 quarter-pixels = 22.5 px -> 22.
  for _ in 0..<30 {
    now += 33334L
    app.advance(now)
  }
  inspect(app.scroll(), content="22")
  // A second second: 60 steps = 180 quarter-pixels = 45 px exactly.
  for _ in 0..<30 {
    now += 33334L
    app.advance(now)
  }
  inspect(app.scroll(), content="45")
}

///|
test "BPM 76 eighth conversion" {
  // One eighth at 76 dotted-quarter BPM is 60000000 / (76 * 3) us
  // = 263157.89...; the first eighth starts at 263158 us.
  inspect(@app.musical_eighths(0L, 76), content="0")
  inspect(@app.musical_eighths(263157L, 76), content="0")
  inspect(@app.musical_eighths(263158L, 76), content="1")
  // One dotted quarter = three eighths.
  inspect(@app.musical_eighths(60000000L, 76), content="228")
  // Six eighths = one 6/8 bar = one full fairy walk cycle.
  inspect(@app.musical_eighths(263158L * 6L, 76), content="6")
}

///|
test "playback position wraps at the canonical PCM duration" {
  let duration = @generated.AUDIO_DURATION_US
  inspect(
    @app.loop_position_us(duration + 1_000_000L, duration),
    content="1000000",
  )
  inspect(
    @app.loop_position_us(duration * 5L + 2500L, duration),
    content="2500",
  )
  inspect(@app.loop_position_us(5_000_000L, duration), content="5000000")
  // Unknown duration pins the position at zero (caller must fall back).
  inspect(@app.loop_position_us(5_000_000L, 0L), content="0")
  // At the App level, positions one loop apart derive the same pose.
  let app = @app.App::new()
  app.advance(0L)
  app.advance(
    33_334L,
    playback_position_us=duration + 5_000_000L,
    presentation_lead_us=0L,
  )
  inspect(app.walker_frame(), content="\{eighths_at(5_000_000L) % 6}")
}

///|
/// Eighth index the app should derive for a live loop-relative position
/// under test (no presentation lead).
fn eighths_at(position_us : Int64) -> Int {
  @app.musical_eighths(position_us, @forest_walk.MUSIC_DOTTED_QUARTER_BPM)
}

///|
test "presentation lead is applied generically" {
  // Lead applies to the loop-relative position, host-agnostically: a lead
  // of L on position P derives the same eighth as position P + L.
  let base = @app.App::new()
  base.advance(0L)
  base.advance(
    33_334L,
    playback_position_us=1_000_000L,
    presentation_lead_us=2_000_000L,
  )
  let direct = @app.App::new()
  direct.advance(0L)
  direct.advance(
    33_334L,
    playback_position_us=3_000_000L,
    presentation_lead_us=0L,
  )
  inspect(base.walker_frame(), content="\{direct.walker_frame()}")
  inspect(direct.walker_frame(), content="\{eighths_at(3_000_000L) % 6}")
}

///|
test "unavailable playback falls back to the monotonic clock" {
  let app = @app.App::new()
  // First tick establishes the baseline only.
  app.advance(0L)
  // Eighth at 76 BPM is ~263158 us; after 1 s of fallback clock the pose
  // is eighths(1s) % 6 = 3 % 6.
  app.advance(1_000_000L)
  inspect(app.walker_frame(), content="3")
  app.advance(2_000_000L)
  inspect(app.walker_frame(), content="1")
  // A zero playback position (audio locked, host reports 0) also falls
  // back instead of freezing the fairy.
  let locked = @app.App::new()
  locked.advance(0L)
  locked.advance(1_000_000L, playback_position_us=0L)
  inspect(locked.walker_frame(), content="3")
  // Live playback then takes over from the fallback clock.
  app.advance(3_000_000L, playback_position_us=10_000_000L)
  inspect(app.walker_frame(), content="\{eighths_at(10_000_000L) % 6}")
}

///|
test "first advance establishes the time baseline" {
  let app = @app.App::new()
  // Host clocks already run before the app boots (browser
  // performance.now(), esp_timer_get_time() after hardware init): the
  // first tick must latch the baseline and simulate none of that time.
  app.advance(10_000_000L)
  inspect(app.frame(), content="0")
  // One 30 Hz period later: exactly one simulation step.
  app.advance(10_033_334L)
  inspect(app.frame(), content="1")
}

///|
test "first tick musical semantics stay deterministic" {
  // The first tick establishes the baseline and runs no steps, so the
  // state holds its initial pose regardless of the host clock's value.
  let live = @app.App::new()
  live.advance(9_000_000L, playback_position_us=5_000_000L)
  inspect(live.walker_frame(), content="0")
  // The next step derives the pose from the audible position alone
  // (stateless), never from the host timestamp.
  live.advance(9_033_334L, playback_position_us=5_000_000L)
  inspect(live.walker_frame(), content="\{eighths_at(5_000_000L) % 6}")
  // Without playback, the first tick banks no fallback time: the beat
  // clock starts at eighth zero regardless of the host clock's value.
  let fallback = @app.App::new()
  fallback.advance(9_000_000L)
  inspect(fallback.walker_frame(), content="0")
  fallback.advance(9_263_158L)
  inspect(fallback.walker_frame(), content="1")
}
