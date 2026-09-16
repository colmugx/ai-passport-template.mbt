///|
/// Host probes into the native test stub's recording of the absolute audio
/// output facts the device adapter mirrored (see host_display_stub.c).
extern "c" fn test_last_output_volume() -> Int = "ai_passport_test_last_output_volume"

///|
extern "c" fn test_last_output_muted() -> Int = "ai_passport_test_last_output_muted"

///|
extern "c" fn test_output_set_calls() -> Int = "ai_passport_test_output_set_calls"

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
}
