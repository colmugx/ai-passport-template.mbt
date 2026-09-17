///|
/// Thin native device entry for the Forest Walk application (the generic AI
/// Passport device ABI). This package is NOT application logic — and not
/// bridge logic either (the SDK `hostabi` owns the C FFI, the display sink,
/// the clock, the battery mapping, the button decoding and the audio
/// mirror): it owns exactly one `@app.App` plus its host adapters and
/// exports the eight ABI symbols the C `app_main` calls. The C host paces
/// frames; all Up/Down/Ok volume/mute semantics live in the shared
/// `@app.App`, exactly as on the wasm/web path.
priv struct DeviceScene {
  app : @app.App
  sink : @hostabi.DeviceDisplaySink
  audio : @hostabi.DeviceAudioMirror
}

///|
priv struct SceneSlot {
  mut scene : DeviceScene?
}

///|
let scene_slot : SceneSlot = { scene: None, }

///|
/// C calls this symbol from app_main to prove MoonBit code is linked and run.
#export_name("ai_passport_mbt_probe")
pub fn probe() -> Int {
  0xA100 | 0x7E
}

///|
#export_name("ai_passport_mbt_app_init")
pub fn app_init() -> Unit {
  if scene_slot.scene is Some(_) {
    abort("Forest Walk device scene initialized twice")
  }
  let app = @app.App::new()
  scene_slot.scene = Some({
    app,
    sink: @hostabi.DeviceDisplaySink::new(),
    audio: @hostabi.DeviceAudioMirror::new(
      initial_volume=app.volume(),
      initial_muted=app.muted(),
    ),
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
#export_name("ai_passport_mbt_app_update")
pub fn app_update() -> Unit {
  let scene = require_scene()
  scene.app.advance(
    @hostabi.device_now_us(),
    playback_position_us?=@hostabi.device_playback_position_us(),
    presentation_lead_us=FAIRY_POSE_LEAD_US,
  )
  scene.audio.sync(scene.app.volume(), muted=scene.app.muted())
}

///|
#export_name("ai_passport_mbt_app_draw")
pub fn app_draw() -> Unit {
  let scene = require_scene()
  scene.app.draw(battery_percent=@hostabi.device_battery_percent())
}

///|
#export_name("ai_passport_mbt_app_present")
pub fn app_present() -> Unit {
  let scene = require_scene()
  @driver.DisplaySink::present(scene.sink, frame=scene.app.frame_view())
}

///|
/// One raw physical button press crossing from the C button bridge into the
/// portable App. The code is a device-neutral fact fixed by the C ABI
/// (`button_bridge.h`): 0 = Up, 1 = Down, 2 = Ok; unknown codes are
/// ignored. The BSP reports a press pulse rather than a clean press/release
/// pair, so the pulse is adapted to the portable input contract: exactly
/// one `just_pressed` edge is latched and immediately released. No control
/// meaning lives here — volume/mute semantics are owned solely by the
/// shared `@app.App`, exactly as on the Wasm/Web path.
#export_name("ai_passport_mbt_input_press")
pub fn input_press(code : Int) -> Unit {
  guard @hostabi.device_button(code) is Some(button) else { return }
  let scene = require_scene()
  scene.app.input(button, true)
  scene.app.input(button, false)
}

///|
/// Read accessor for the App's remembered volume (0..=100), handed to C at
/// music start so the App is authoritative before the first PCM sample; C
/// never hard-codes a startup volume of its own.
#export_name("ai_passport_mbt_audio_volume")
pub fn audio_volume() -> Int {
  require_scene().app.volume()
}

///|
/// Read accessor for the App's mute flag, returned as the C ABI integers
/// 1 (muted) / 0 (audible). Only OK clears the mute; the codec is driven at
/// 0 while the remembered volume is preserved.
#export_name("ai_passport_mbt_audio_muted")
pub fn audio_muted() -> Int {
  if require_scene().app.muted() {
    1
  } else {
    0
  }
}
