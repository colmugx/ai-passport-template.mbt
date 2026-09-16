///|
/// Absolute desired audio output facts crossing into the C music transport.
/// The App owns every control semantic; this adapter only mirrors state, the
/// device-side analogue of runtime_wasm's `sync_audio_state`. The transport
/// itself applies the state in the music task between bounded PCM writes.
extern "c" fn audio_set_output(volume : Int, muted : Int) -> Unit = "ai_passport_music_set_output"

///|
/// Device-only read accessor for the App's remembered volume (0..=100).
/// app_main passes this to `ai_passport_music_start` so the App is
/// authoritative before the first PCM sample; C never hard-codes a startup
/// volume of its own.
#export_name("ai_passport_mbt_audio_volume")
pub fn audio_volume() -> Int {
  require_scene().app.volume()
}

///|
/// Device-only read accessor for the App's mute flag, returned as the C ABI
/// integers 1 (muted) / 0 (audible).
#export_name("ai_passport_mbt_audio_muted")
pub fn audio_muted() -> Int {
  if require_scene().app.muted() {
    1
  } else {
    0
  }
}

///|
/// Mirrors the App's absolute desired output to the transport when it
/// changed. Called once per rendered frame, after `App::advance` has applied
/// any latched button edges, so one delivered press crosses into C at most
/// once. Identical state never reaches the transport (the music task skips
/// redundant codec writes on top of that).
fn sync_audio_output(scene : DeviceScene) -> Unit {
  let volume = scene.app.volume()
  let muted = scene.app.muted()
  if volume != scene.applied_volume || muted != scene.applied_muted {
    audio_set_output(volume, if muted { 1 } else { 0 })
    scene.applied_volume = volume
    scene.applied_muted = muted
  }
}
