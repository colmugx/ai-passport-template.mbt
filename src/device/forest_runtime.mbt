///|
/// The C ABI sees only small entry functions. MoonBit retains the portable
/// application, logical framebuffer and display sink for the entire device
/// run. The application itself (Forest Walk state, fixed-step 30 Hz timing,
/// musical position, volume/mute semantics) lives in `src/app`, shared
/// unchanged with the wasm web host.
priv struct DeviceScene {
  app : @app.App
  sink : EspDisplaySink
  // Last audio output state mirrored to the music transport, initialized
  // from the App so a fresh scene crosses no redundant write (the transport
  // receives the same App facts explicitly at music start).
  mut applied_volume : Int
  mut applied_muted : Bool
}

///|
priv struct SceneSlot {
  mut scene : DeviceScene?
}

///|
let scene_slot : SceneSlot = { scene: None, }

///|
#export_name("ai_passport_mbt_forest_init")
pub fn forest_init() -> Unit {
  if scene_slot.scene is Some(_) {
    abort("Forest Walk device scene initialized twice")
  }
  let app = @app.App::new()
  scene_slot.scene = Some({
    app,
    sink: EspDisplaySink::new(),
    applied_volume: app.volume(),
    applied_muted: app.muted(),
  })
}

///|
fn require_scene() -> DeviceScene {
  match scene_slot.scene {
    Some(scene) => scene
    None => abort("Forest Walk device scene used before initialization")
  }
}

///|
/// The device pose clock leads the reported playback position by this much.
/// Measured on hardware: with no lead the fairy's displayed steps landed
/// clearly after the audible beat; +150 ms overshot into a slight early
/// lead; 100 ms lands on the beat (a few ms late is chosen over early,
/// which the eye catches faster than the ear). Browser preview timing is
/// unaffected. This is a host calibration fact handed to the portable app,
/// not device application logic.
const FAIRY_POSE_LEAD_US : Int64 = 100_000L

///|
/// One C-paced frame tick: the app receives the monotonic device clock and
/// the transport's playback Option (`Some(position)` — loop-boundary zero
/// included — while the streaming task runs, `None` when it does not), and
/// itself decides when logical 30 Hz simulation steps occur. The 100 ms
/// fairy-pose lead is passed as the generic presentation-lead fact. Any
/// physical press the frame task delivered to the App has already been
/// applied here; afterwards the absolute desired output is mirrored to the
/// music transport.
#export_name("ai_passport_mbt_forest_update")
pub fn forest_update() -> Unit {
  let scene = require_scene()
  scene.app.advance(
    device_now_us(),
    playback_position_us?=device_playback_position_us(),
    presentation_lead_us=FAIRY_POSE_LEAD_US,
  )
  sync_audio_output(scene)
}

///|
#export_name("ai_passport_mbt_forest_draw")
pub fn forest_draw() -> Unit {
  let scene = require_scene()
  scene.app.draw(battery_percent=device_battery_percent())
}

///|
#export_name("ai_passport_mbt_forest_present")
pub fn forest_present() -> Unit {
  let scene = require_scene()
  @driver.DisplaySink::present(scene.sink, frame=scene.app.frame_view())
}
