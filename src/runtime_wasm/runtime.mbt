///|
/// Thin Wasm entry package for the Forest Walk application (ABI v0). This
/// package is NOT application logic: it owns exactly one `@app.App`, adapts
/// SDK hostabi facts into App inputs, exports the ABI v0 lifecycle
/// functions, presents `App::frame_view` through the SDK `HostBridge`, and
/// applies App volume/mute state to `host_set_volume`/`host_set_muted`.
/// `main` returns after initialization; the JS host paces frames.
///
/// PCM asset mode (SDK 0.0.2) makes the streamed `host_pcm_write` producer
/// and the host-configured `pcmAssetUrl` mode mutually exclusive. Forest
/// Walk plays the canonical normalized PCM artifact, so the bridge here is
/// built through the public `HostBridge::new` constructor with a no-op PCM
/// closure and the real `store_u16`/`host_battery_percent` imports — the
/// built module therefore never declares `passport.host_pcm_write` (CI
/// asserts this with `WebAssembly.Module.imports()`).
priv struct Runtime {
  bridge : @hostabi.HostBridge
  app : @app.App
  battery : @battery.Battery
  // Host-applied volume/mute mirrors; only deltas cross the imports.
  mut applied_volume : Int
  mut applied_muted : Bool
}

///|
/// The no-op PCM closure keeping `host_pcm_write` out of the module.
fn pcm_noop(ptr : Int, samples : Int) -> Unit {
  let _ = ptr
  let _ = samples
}

///|
fn Runtime::make() -> Runtime {
  let bridge = @hostabi.HostBridge::new(
    store_u16=@hostabi.store_u16,
    pcm_write=pcm_noop,
    battery_percent=@hostabi.host_battery_percent,
  )
  let source : &@battery.BatterySource = bridge
  let app = @app.App::new()
  {
    bridge,
    app,
    battery: @battery.Battery::new(source~),
    applied_volume: app.volume(),
    applied_muted: app.muted(),
  }
}

///|
/// Package-level runtime state. Toplevel initialization runs before `_start`
/// returns, and the host calls no `passport_*` export before `_start`, so
/// every export sees fully built state.
let state : Runtime = Runtime::make()

///|
/// Wasm entry point (exported as `_start`): one-time initialization, then
/// return. Mirrors the startup volume/mute state to the host exactly once
/// (also keeping both imports live in every build profile).
fn main {
  @hostabi.host_set_volume(state.app.volume())
  @hostabi.host_set_muted(if state.app.muted() { 1 } else { 0 })
  state.applied_volume = state.app.volume()
  state.applied_muted = state.app.muted()
}

///|
/// Applies App volume/mute deltas to the host imports. The App owns the
/// semantics (clamps, remembered volume, mute toggling); this side only
/// mirrors state changes.
fn sync_audio_state(rt : Runtime) -> Unit {
  let volume = rt.app.volume()
  if volume != rt.applied_volume {
    @hostabi.host_set_volume(volume)
    rt.applied_volume = volume
  }
  let muted = rt.app.muted()
  if muted != rt.applied_muted {
    @hostabi.host_set_muted(if muted { 1 } else { 0 })
    rt.applied_muted = muted
  }
}
