///|
/// Host probes into the native test stub's recording of the absolute audio
/// output facts the device adapter mirrored (see host_display_stub.c).
extern "c" fn test_last_output_volume() -> Int = "ai_passport_test_last_output_volume"

///|
extern "c" fn test_last_output_muted() -> Int = "ai_passport_test_last_output_muted"

///|
extern "c" fn test_output_set_calls() -> Int = "ai_passport_test_output_set_calls"

///|
/// Host transport hooks (see host_display_stub.c): drive the availability
/// fact, the music position and the frame clock exactly as the firmware
/// reports them.
extern "c" fn test_set_music_available(available : Int) -> Unit = "ai_passport_test_set_music_available"

///|
extern "c" fn test_set_music_position(position_us : Int64) -> Unit = "ai_passport_test_set_music_position"

///|
extern "c" fn test_set_now_us(now_us : Int64) -> Unit = "ai_passport_test_set_now_us"

///|
/// Test seam: allows this control-path test to construct its own fresh
/// scene regardless of test execution order (white-box access to the
/// package slot).
fn reset_scene_for_test() -> Unit {
  scene_slot.scene = None
}

///|
/// Proves the physical-button control path at the device-adapter level:
/// a delivered press pulse reaches the SAME shared @app.App the Wasm path
/// uses, and only the changed absolute output facts cross into the music
/// transport. All control arithmetic (step 10, clamping, remembered mute
/// volume) lives in @app and is asserted there; this test never repeats it.
test "device adapter delivers physical presses through the shared App" {
  reset_scene_for_test()
  forest_init()
  // Initial App output facts are 80 / unmuted, and nothing has crossed into
  // the transport yet: app_main passes these accessors to music start
  // explicitly, so the mirror only fires on later changes.
  assert_eq(audio_volume(), 80)
  assert_eq(audio_muted(), 0)
  assert_eq(test_output_set_calls(), 0)
  // UP pulse reaches the App: one press -> one action -> absolute output
  // 90 mirrored to the transport.
  input_press(0)
  forest_update()
  assert_eq(audio_volume(), 90)
  assert_eq(test_last_output_volume(), 90)
  assert_eq(test_last_output_muted(), 0)
  let calls_after_up = test_output_set_calls()
  // A frame without a press repeats nothing.
  forest_update()
  assert_eq(test_output_set_calls(), calls_after_up)
  // DOWN pulse reaches the App.
  input_press(1)
  forest_update()
  assert_eq(audio_volume(), 80)
  assert_eq(test_last_output_volume(), 80)
  // OK pulse reaches the App: muted, remembered volume preserved.
  input_press(2)
  forest_update()
  assert_eq(audio_muted(), 1)
  assert_eq(test_last_output_muted(), 1)
  assert_eq(test_last_output_volume(), 80)
  // UP while muted moves the remembered volume but stays muted.
  input_press(0)
  forest_update()
  assert_eq(audio_volume(), 90)
  assert_eq(audio_muted(), 1)
  assert_eq(test_last_output_volume(), 90)
  assert_eq(test_last_output_muted(), 1)
  // OK unmutes and the remembered volume is restored.
  input_press(2)
  forest_update()
  assert_eq(audio_muted(), 0)
  assert_eq(test_last_output_muted(), 0)
  assert_eq(test_last_output_volume(), 90)
  // Unknown physical button codes do nothing at all.
  let calls_before_unknown = test_output_set_calls()
  input_press(3)
  input_press(-1)
  forest_update()
  assert_eq(test_output_set_calls(), calls_before_unknown)
  assert_eq(audio_volume(), 90)
  assert_eq(audio_muted(), 0)
  // One delivered pulse produces exactly one action: UP from 90 lands at
  // 100 (a doubled application would also clamp here, so DOWN is the
  // discriminating direction below), then one DOWN lands at 90 — not 80.
  input_press(0)
  forest_update()
  assert_eq(audio_volume(), 100)
  input_press(1)
  forest_update()
  assert_eq(audio_volume(), 90)
  // Leave the shared stub clocks where later tests expect them.
  test_set_now_us(0)
}

///|
/// Proves the playback-availability contract at the device-adapter level:
/// the transport's availability fact decides the playback Option the App
/// receives, and a live position of exactly zero reaches the App as live
/// playback — never as the unavailable state. No musical arithmetic lives
/// in the adapter; every expectation below comes from the shared App's own
/// eighth conversion.
test "device adapter maps transport availability to the App playback Option" {
  reset_scene_for_test()
  forest_init()
  // Unavailable transport (startup failed): the adapter hands the App None,
  // so the fallback beat clock accumulates real host time — two seconds of
  // frames reach eighth 7 -> pose 7 * 3 / 4 = 5. A wrongly forwarded
  // Some(0) would pin the pose at 0.
  test_set_music_available(0)
  test_set_music_position(0)
  test_set_now_us(0)
  forest_update()
  test_set_now_us(2_000_000L)
  forest_update()
  assert_eq(require_scene().app.walker_frame(), 5)
  // Fresh scene, live transport at the loop boundary: position exactly 0 is
  // LIVE. The same two seconds of host time must leave the pose at eighth 0
  // — the fallback clock stays untouched because the App received Some(0).
  reset_scene_for_test()
  forest_init()
  test_set_music_available(1)
  test_set_music_position(0)
  test_set_now_us(0)
  forest_update()
  test_set_now_us(2_000_000L)
  forest_update()
  assert_eq(require_scene().app.walker_frame(), 0)
  // A nonzero live position rides the PCM timeline through the same Option:
  // 600 ms = eighth 2 -> pose 2 * 3 / 4 = 1. The clock also advances one
  // frame so a simulation step refreshes the rendered pose.
  test_set_music_position(600_000L)
  test_set_now_us(2_033_334L)
  forest_update()
  assert_eq(require_scene().app.walker_frame(), 1)
  // Restore the shared stub state for other tests.
  test_set_music_available(0)
  test_set_music_position(0)
  test_set_now_us(0)
}
