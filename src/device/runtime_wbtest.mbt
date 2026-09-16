///|
test "device runtime drives the portable app over the host stubs" {
  // Host stubs freeze both clocks at zero: no simulation steps run, the
  // playback position is unavailable (0) and the fallback clock never
  // advances, so the scene holds its initial pose.
  forest_init()
  forest_update()
  forest_draw()
  let scene = require_scene()
  assert_eq(scene.app.frame(), 0)
  assert_eq(scene.app.walker_frame(), 0)
  assert_eq(scene.app.scroll(), 0)
  // The app is the same portable application the wasm host runs: startup
  // volume 80, audible.
  assert_eq(scene.app.volume(), 80)
  assert_eq(scene.app.muted(), false)
}

///|
test "device fairy pose lead stays the hardware-measured 100 ms" {
  assert_eq(FAIRY_POSE_LEAD_US, 100_000L)
}
