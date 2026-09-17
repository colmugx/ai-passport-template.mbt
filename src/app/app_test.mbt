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
test "scroll advances at 16.875 logical px/s" {
  let app = @app.App::new()
  let mut now = 0L
  // Establish the baseline: the first tick simulates no pre-boot time.
  app.advance(now)
  // One second of simulation: 30 steps = 270 sixteenth-pixels
  // = 16.875 px -> 16 (three quarters of the old 22.5 px/s pace, matching
  // the 4/4 walk cycle so a footstep still covers the same ground).
  for _ in 0..<30 {
    now += 33334L
    app.advance(now)
  }
  inspect(app.scroll(), content="16")
  // A second second: 60 steps = 540 sixteenth-pixels = 33.75 px -> 33.
  for _ in 0..<30 {
    now += 33334L
    app.advance(now)
  }
  inspect(app.scroll(), content="33")
}

///|
/// R3A timing golden guard. Pins the intentional d50596d product cadence so
/// a future renderer or scheduler "optimization" cannot silently restore
/// the old behavior (22.5 px/s quarter-pixel scroll, one pose per eighth):
/// the scroll golden above (30 updates -> 16, 60 updates -> 33) and the
/// full eighth-to-pose mapping of the production App — six poses spread
/// across the eight eighths of one 4/4 bar, pose 0 on the downbeat and
/// again on the wrap at eighth 8. Positions are live playback facts at one
/// eighth per 263_158 us, exactly what hosts feed.
test "timing golden: 16.875 px/s scroll and eighth-to-pose sequence" {
  let app = @app.App::new()
  let mut now = 0L
  app.advance(now)
  for _ in 0..<30 {
    now += 33334L
    app.advance(now)
  }
  assert_eq(app.scroll(), 16)
  for _ in 0..<30 {
    now += 33334L
    app.advance(now)
  }
  assert_eq(app.scroll(), 33)
  // Eighth index e realized as a live playback position; the production
  // App chain (position -> loop wrap -> eighth -> State::update pose).
  let poses : Array[Int] = [0, 0, 1, 2, 3, 3, 4, 5, 0]
  let beat = @app.App::new()
  beat.advance(0L)
  let mut t = 0L
  for e in 0..<9 {
    t += 33334L
    beat.advance(t, playback_position_us=(e * 263_158).to_int64())
    assert_eq(beat.walker_frame(), poses[e])
  }
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
  // Eight eighths = one 4/4 bar = one full fairy walk cycle (the scene
  // maps six poses onto those eight eighths).
  inspect(@app.musical_eighths(263158L * 8L, 76), content="8")
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
  inspect(app.walker_frame(), content="\{pose_at(5_000_000L)}")
}

///|
/// Eighth index the app should derive for a live loop-relative position
/// under test (no presentation lead).
fn eighths_at(position_us : Int64) -> Int {
  @app.musical_eighths(position_us, @forest_walk.MUSIC_DOTTED_QUARTER_BPM)
}

///|
/// Fairy pose the app should render for a live loop-relative position under
/// test: six poses spread across the eight-eighth 4/4 bar, so one pose
/// lasts 4/3 eighths.
fn pose_at(position_us : Int64) -> Int {
  eighths_at(position_us) * 3 / 4 % 6
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
  inspect(direct.walker_frame(), content="\{pose_at(3_000_000L)}")
}

///|
test "unavailable playback falls back to the monotonic clock" {
  let app = @app.App::new()
  // First tick establishes the baseline only.
  app.advance(0L)
  // None (playback unavailable): an eighth at 76 BPM is ~263158 us; after
  // 1 s of fallback clock eighths(1s) = 3 -> pose 3 * 3 / 4 = 2.
  app.advance(1_000_000L, playback_position_us?=None)
  inspect(app.walker_frame(), content="2")
  app.advance(2_000_000L, playback_position_us?=None)
  // eighths(2s) = 7 -> pose 7 * 3 / 4 = 5.
  inspect(app.walker_frame(), content="5")
  // Live playback then takes over from the fallback clock.
  app.advance(3_000_000L, playback_position_us=10_000_000L)
  inspect(app.walker_frame(), content="\{pose_at(10_000_000L)}")
}

///|
test "None means fallback: the beat clock advances from frame deltas" {
  let app = @app.App::new()
  app.advance(0L, playback_position_us?=None)
  // No host time banked on the baseline tick: eighth zero.
  inspect(app.walker_frame(), content="0")
  // Two and a half seconds of host time with None reports: the fallback
  // clock accumulates deltas and reaches eighths(2.5 s) = 9 -> pose 6.
  app.advance(2_500_000L, playback_position_us?=None)
  inspect(app.walker_frame(), content="\{pose_at(2_500_000L)}")
}

///|
test "Some(0) means live playback, not the fallback clock" {
  let app = @app.App::new()
  // A large presentation lead lifts the live zero position far past eighth
  // zero (eighths(10 s) = 38 -> pose 4), while the fallback path on these two
  // ticks would still be pinned at eighth zero — the assertion cannot pass
  // by accident.
  app.advance(
    0L,
    playback_position_us=0L,
    presentation_lead_us=10_000_000L,
  )
  app.advance(
    33_334L,
    playback_position_us=0L,
    presentation_lead_us=10_000_000L,
  )
  inspect(app.walker_frame(), content="\{pose_at(10_000_000L)}")
}

///|
test "exact loop boundary stays on the live PCM timeline" {
  let duration = @generated.AUDIO_DURATION_US
  let app = @app.App::new()
  app.advance(0L)
  // Near the end of the loop the pose follows the live timeline.
  app.advance(33_334L, playback_position_us=duration - 1_000L)
  inspect(app.walker_frame(), content="\{pose_at(duration - 1_000L)}")
  // The transport wraps: the very next live report is exactly 0, and it is
  // still live — pose derived from the PCM timeline, not the fallback.
  app.advance(66_668L, playback_position_us=0L)
  // Follow-up live positions keep riding the loop: eighth of 500 ms.
  app.advance(100_002L, playback_position_us=500_000L)
  inspect(app.walker_frame(), content="\{pose_at(500_000L)}")
  // If either Some(0) had been treated as unavailable, the fallback clock
  // would only have ~66_668 us banked here — eighth 0, pose 0 — and both
  // assertions above would fail.
}

///|
test "live zero positions never advance the fallback beat clock" {
  let app = @app.App::new()
  app.advance(0L, playback_position_us=0L)
  // Two seconds of host time while playback reports a live zero (track
  // start / loop boundary): the fallback clock must stay untouched, so the
  // pose is the live eighth 0 — not eighths(2 s) % 6 = 1.
  app.advance(2_000_000L, playback_position_us=0L)
  inspect(app.walker_frame(), content="0")
  // The moment reports stop, the fallback takes over from scratch: 1 s of
  // delta reaches eighth 3 -> pose 2, proving nothing was banked during
  // playback.
  app.advance(3_000_000L, playback_position_us?=None)
  inspect(app.walker_frame(), content="2")
}

///|
test "negative playback positions fall back safely" {
  let app = @app.App::new()
  app.advance(0L)
  // No healthy host emits a negative position; if one ever arrives it is
  // treated as unavailable and the fallback clock keeps the fairy moving.
  app.advance(1_000_000L, playback_position_us=-5L)
  inspect(app.walker_frame(), content="2")
  app.advance(2_000_000L, playback_position_us=-500_000_000L)
  inspect(app.walker_frame(), content="5")
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
  inspect(live.walker_frame(), content="\{pose_at(5_000_000L)}")
  // Without playback, the first tick banks no fallback time: the beat
  // clock starts at eighth zero regardless of the host clock's value.
  let fallback = @app.App::new()
  fallback.advance(9_000_000L)
  inspect(fallback.walker_frame(), content="0")
  fallback.advance(9_263_158L)
  inspect(fallback.walker_frame(), content="0")
}
